"""
Load most_popular slim files to BigQuery staging, MERGE to final table, and update manifest.
"""

import json
import logging
from datetime import UTC, datetime
from pathlib import Path

from config import (
    BQ_STAGING_DATASET,
    GCP_PROJECT,
    LOAD_MANIFEST_TABLE,
    MOST_POPULAR_FINAL_TABLE,
    MOST_POPULAR_STAGING_TABLE,
)
from google.cloud import bigquery

logger = logging.getLogger(__name__)


def load_most_popular(bucket: str, object_name: str, snapshot_date: str) -> None:
    """
    Load one most_popular_slim NDJSON file to staging, MERGE to final table, and update manifest.

    Args:
        bucket: GCS bucket name
        object_name: Full object path (e.g. prefix/most_popular_slim/2026-02-19/viewed_30.ndjson)
        snapshot_date: Snapshot date (YYYY-MM-DD) extracted from path
    """
    client = bigquery.Client(project=GCP_PROJECT)
    gcs_uri = f"gs://{bucket}/{object_name}"
    manifest_path = object_name

    logger.info(
        "Loading most_popular from %s to %s (snapshot_date=%s)",
        gcs_uri,
        MOST_POPULAR_STAGING_TABLE,
        snapshot_date,
    )

    # Check if already loaded
    check_query = f"""
        SELECT COUNT(*) as count
        FROM `{GCP_PROJECT}.{LOAD_MANIFEST_TABLE}`
        WHERE source = 'most_popular_slim' AND path = '{manifest_path}'
    """
    check_result = list(client.query(check_query).result())
    if check_result and check_result[0].count > 0:
        logger.info(f"Path {manifest_path} already loaded, skipping")
        return

    # Load to a temp table first, then INSERT with snapshot_date
    temp_table = f"{MOST_POPULAR_STAGING_TABLE}_temp"

    # Get schema without snapshot_date for loading
    schema_path = Path(__file__).parent.parent / "schema" / "most_popular_articles.json"
    with open(schema_path) as f:
        full_schema_json = json.load(f)
    # Remove snapshot_date from schema for temp load; build schema from API repr list
    temp_schema_json = [field for field in full_schema_json if field["name"] != "snapshot_date"]
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

    load_job = client.load_table_from_uri(
        gcs_uri, f"{GCP_PROJECT}.{temp_table}", job_config=job_config
    )
    load_job.result()
    logger.info(f"Loaded {load_job.output_rows} rows to temp table")

    # Insert into staging with snapshot_date
    insert_query = f"""
        INSERT INTO `{GCP_PROJECT}.{MOST_POPULAR_STAGING_TABLE}`
        SELECT
            DATE('{snapshot_date}') as snapshot_date,
            *
        FROM `{GCP_PROJECT}.{temp_table}`
    """
    insert_job = client.query(insert_query)
    insert_job.result()
    logger.info(f"Inserted rows to staging with snapshot_date={snapshot_date}")

    # Drop temp table
    client.delete_table(f"{GCP_PROJECT}.{temp_table}", not_found_ok=True)

    # MERGE to final table (dedup by snapshot_date, id)
    merge_query = f"""
        MERGE `{GCP_PROJECT}.{MOST_POPULAR_FINAL_TABLE}` AS target
        USING `{GCP_PROJECT}.{MOST_POPULAR_STAGING_TABLE}` AS source
        ON target.snapshot_date = source.snapshot_date AND target.id = source.id
        WHEN NOT MATCHED THEN
            INSERT ROW
    """
    merge_job = client.query(merge_query)
    merge_job.result()
    logger.info("MERGE to most_popular_articles completed")

    # Insert manifest entry
    now = datetime.now(UTC).isoformat()
    manifest_query = f"""
        INSERT INTO `{GCP_PROJECT}.{LOAD_MANIFEST_TABLE}` (source, path, loaded_at)
        VALUES ('most_popular_slim', '{manifest_path}', TIMESTAMP('{now}'))
    """
    manifest_job = client.query(manifest_query)
    manifest_job.result()
    logger.info(f"Manifest updated for path: {manifest_path}")

    # Truncate staging
    truncate_query = f"TRUNCATE TABLE `{GCP_PROJECT}.{MOST_POPULAR_STAGING_TABLE}`"
    truncate_job = client.query(truncate_query)
    truncate_job.result()
    logger.info("Staging table truncated")
