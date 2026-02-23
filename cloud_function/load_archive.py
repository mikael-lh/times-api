"""
Load archive slim files to BigQuery staging, MERGE to final table, and update manifest.
"""

import logging
from datetime import UTC, datetime
from pathlib import Path

from config import (
    ARCHIVE_FINAL_TABLE,
    ARCHIVE_STAGING_TABLE,
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

    # Load to staging
    schema_path = Path(__file__).parent.parent / "schema" / "archive_articles.json"
    schema = client.schema_from_json(str(schema_path))

    job_config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.NEWLINE_DELIMITED_JSON,
        schema=schema,
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
    )

    load_job = client.load_table_from_uri(gcs_uri, ARCHIVE_STAGING_TABLE, job_config=job_config)
    load_job.result()
    logger.info(f"Loaded {load_job.output_rows} rows to staging")

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
