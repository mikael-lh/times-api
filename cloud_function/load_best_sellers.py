"""
Load Best Sellers slim files to BigQuery staging, MERGE to final table, and update manifest.

The slim NDJSON arrives with published_date as a STRING (YYYY-MM-DD). We load
to a temp table with published_date typed as STRING, then INSERT into staging
casting to DATE, mirroring the archive loader's pattern.
"""

import json
import logging
from datetime import UTC, datetime
from pathlib import Path

from config import (
    BEST_SELLERS_FINAL_TABLE,
    BEST_SELLERS_STAGING_TABLE,
    BQ_STAGING_DATASET,
    GCP_PROJECT,
    LOAD_MANIFEST_TABLE,
)
from google.cloud import bigquery

logger = logging.getLogger(__name__)


def load_best_sellers(bucket: str, object_name: str) -> None:
    """
    Load one books_slim NDJSON file to staging, MERGE to final table, and update manifest.

    Args:
        bucket: GCS bucket name
        object_name: Full object path (e.g. "nyt-ingest/books_slim/2025-05-04/overview.ndjson")
    """
    client = bigquery.Client(project=GCP_PROJECT)
    gcs_uri = f"gs://{bucket}/{object_name}"
    manifest_path = object_name

    logger.info(f"Loading best_sellers from {gcs_uri} to {BEST_SELLERS_STAGING_TABLE}")

    check_query = f"""
        SELECT COUNT(*) as count
        FROM `{GCP_PROJECT}.{LOAD_MANIFEST_TABLE}`
        WHERE source = 'books_slim' AND path = '{manifest_path}'
    """
    check_result = list(client.query(check_query).result())
    if check_result and check_result[0].count > 0:
        logger.info(f"Path {manifest_path} already loaded, skipping")
        return

    temp_table = f"{BEST_SELLERS_STAGING_TABLE}_temp"

    schema_path = Path(__file__).parent / "schema" / "best_sellers.json"
    with open(schema_path) as f:
        full_schema_json = json.load(f)
    temp_schema_json = full_schema_json.copy()
    for field in temp_schema_json:
        if field["name"] == "published_date":
            field["type"] = "STRING"
            field["description"] = (
                "Publication date (YYYY-MM-DD STRING, converted to DATE on INSERT)"
            )
            break
    temp_schema = [bigquery.SchemaField.from_api_repr(f) for f in temp_schema_json]

    temp_table_ref = client.dataset(BQ_STAGING_DATASET).table(temp_table.split(".")[-1])
    temp_table_obj = bigquery.Table(temp_table_ref, schema=temp_schema)
    client.create_table(temp_table_obj, exists_ok=True)

    job_config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.NEWLINE_DELIMITED_JSON,
        schema=temp_schema,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
    )

    load_job = client.load_table_from_uri(
        gcs_uri, f"{GCP_PROJECT}.{temp_table}", job_config=job_config
    )
    load_job.result()
    logger.info(f"Loaded {load_job.output_rows} rows to temp table")

    insert_query = f"""
        INSERT INTO `{GCP_PROJECT}.{BEST_SELLERS_STAGING_TABLE}`
        SELECT
            SAFE.PARSE_DATE('%Y-%m-%d', published_date) AS published_date,
            list_name_encoded,
            list_display_name,
            list_updated,
            rank,
            rank_last_week,
            weeks_on_list,
            asterisk,
            dagger,
            primary_isbn13,
            title,
            author,
            contributor,
            contributor_note,
            publisher,
            description,
            book_image,
            amazon_product_url,
            age_group,
            book_review_link,
            sunday_review_link
        FROM `{GCP_PROJECT}.{temp_table}`
    """
    insert_job = client.query(insert_query)
    insert_job.result()
    logger.info("Inserted rows to staging with published_date converted to DATE")

    client.delete_table(f"{GCP_PROJECT}.{temp_table}", not_found_ok=True)

    # MERGE to final table (dedup by published_date, list_name_encoded, rank,
    # list_updated). Rank is the natural per-week, per-list key; list_updated
    # distinguishes weekly vs monthly variants on early overview responses.
    merge_query = f"""
        MERGE `{GCP_PROJECT}.{BEST_SELLERS_FINAL_TABLE}` AS target
        USING `{GCP_PROJECT}.{BEST_SELLERS_STAGING_TABLE}` AS source
        ON  target.published_date = source.published_date
        AND target.list_name_encoded = source.list_name_encoded
        AND target.rank = source.rank
        AND target.list_updated = source.list_updated
        WHEN NOT MATCHED THEN
            INSERT ROW
    """
    merge_job = client.query(merge_query)
    merge_job.result()
    logger.info("MERGE to best_sellers completed")

    now = datetime.now(UTC).isoformat()
    manifest_query = f"""
        INSERT INTO `{GCP_PROJECT}.{LOAD_MANIFEST_TABLE}` (source, path, loaded_at)
        VALUES ('books_slim', '{manifest_path}', TIMESTAMP('{now}'))
    """
    manifest_job = client.query(manifest_query)
    manifest_job.result()
    logger.info(f"Manifest updated for path: {manifest_path}")

    truncate_query = f"TRUNCATE TABLE `{GCP_PROJECT}.{BEST_SELLERS_STAGING_TABLE}`"
    truncate_job = client.query(truncate_query)
    truncate_job.result()
    logger.info("Staging table truncated")
