"""
Load archive slim files to BigQuery staging, MERGE to final table, and update manifest.
"""

import json
import logging
from datetime import UTC, datetime
from pathlib import Path

from config import (
    ARCHIVE_FINAL_TABLE,
    ARCHIVE_STAGING_TABLE,
    BQ_STAGING_DATASET,
    GCP_PROJECT,
    LOAD_MANIFEST_TABLE,
)
from google.cloud import bigquery

logger = logging.getLogger(__name__)


def load_archive(bucket: str, object_name: str) -> None:
    """
    Load one archive_slim NDJSON file to staging, MERGE to final table, and update manifest.

    Args:
        bucket: GCS bucket name
        object_name: Full object path (e.g. "nyt-ingest/archive_slim/2020/05.ndjson")
    """
    client = bigquery.Client(project=GCP_PROJECT)
    gcs_uri = f"gs://{bucket}/{object_name}"
    manifest_path = object_name

    logger.info(f"Loading archive from {gcs_uri} to {ARCHIVE_STAGING_TABLE}")

    # Check if already loaded
    check_query = f"""
        SELECT COUNT(*) as count
        FROM `{GCP_PROJECT}.{LOAD_MANIFEST_TABLE}`
        WHERE source = 'archive_slim' AND path = '{manifest_path}'
    """
    check_result = list(client.query(check_query).result())
    if check_result and check_result[0].count > 0:
        logger.info(f"Path {manifest_path} already loaded, skipping")
        return

    # Load to a temp table first, then INSERT with pub_date conversion
    temp_table = f"{ARCHIVE_STAGING_TABLE}_temp"

    # Get schema with pub_date STRING for temp load
    schema_path = Path(__file__).parent.parent / "schema" / "archive_articles.json"
    with open(schema_path) as f:
        full_schema_json = json.load(f)
    # Change pub_date to STRING for temp load; build schema from API repr list
    temp_schema_json = full_schema_json.copy()
    for field in temp_schema_json:
        if field["name"] == "pub_date":
            field["type"] = "STRING"
            field["description"] = "Publication date (ISO or YYYY-MM-DD, converted to DATE on INSERT)"
            break
    temp_schema = [bigquery.SchemaField.from_api_repr(f) for f in temp_schema_json]

    # Create temp table
    temp_table_ref = client.dataset(BQ_STAGING_DATASET).table(temp_table.split(".")[-1])
    temp_table_obj = bigquery.Table(temp_table_ref, schema=temp_schema)
    client.create_table(temp_table_obj, exists_ok=True)

    # Load to temp
    job_config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.NEWLINE_DELIMITED_JSON,
        schema=temp_schema,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
    )

    load_job = client.load_table_from_uri(gcs_uri, f"{GCP_PROJECT}.{temp_table}", job_config=job_config)
    load_job.result()
    logger.info(f"Loaded {load_job.output_rows} rows to temp table")

    # Insert into staging with pub_date conversion (first 10 chars = YYYY-MM-DD)
    insert_query = f"""
        INSERT INTO `{GCP_PROJECT}.{ARCHIVE_STAGING_TABLE}`
        SELECT
            article_id,
            uri,
            SAFE.PARSE_DATE('%Y-%m-%d', SUBSTR(pub_date, 1, 10)) AS pub_date,
            section_name,
            news_desk,
            type_of_material,
            document_type,
            word_count,
            web_url,
            headline_main,
            byline_original,
            abstract,
            snippet,
            keywords,
            byline_person,
            multimedia_count_by_type
        FROM `{GCP_PROJECT}.{temp_table}`
    """
    insert_job = client.query(insert_query)
    insert_job.result()
    logger.info("Inserted rows to staging with pub_date converted to DATE")

    # Drop temp table
    client.delete_table(f"{GCP_PROJECT}.{temp_table}", not_found_ok=True)

    # MERGE to final table (dedup by article_id)
    merge_query = f"""
        MERGE `{GCP_PROJECT}.{ARCHIVE_FINAL_TABLE}` AS target
        USING `{GCP_PROJECT}.{ARCHIVE_STAGING_TABLE}` AS source
        ON target.article_id = source.article_id
        WHEN NOT MATCHED THEN
            INSERT ROW
    """
    merge_job = client.query(merge_query)
    merge_job.result()
    logger.info("MERGE to archive_articles completed")

    # Insert manifest entry
    now = datetime.now(UTC).isoformat()
    manifest_query = f"""
        INSERT INTO `{GCP_PROJECT}.{LOAD_MANIFEST_TABLE}` (source, path, loaded_at)
        VALUES ('archive_slim', '{manifest_path}', TIMESTAMP('{now}'))
    """
    manifest_job = client.query(manifest_query)
    manifest_job.result()
    logger.info(f"Manifest updated for path: {manifest_path}")

    # Truncate staging
    truncate_query = f"TRUNCATE TABLE `{GCP_PROJECT}.{ARCHIVE_STAGING_TABLE}`"
    truncate_job = client.query(truncate_query)
    truncate_job.result()
    logger.info("Staging table truncated")
