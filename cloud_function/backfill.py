"""
One-off backfill: load existing GCS files into BigQuery using the same logic as the Cloud Function.

Lists all objects under archive_slim/ and most_popular_slim/ in the configured bucket/prefix,
then calls load_archive() or load_most_popular() for each. Skips files already in the manifest
(same idempotency as the function).

Run from project root with env vars set (same as deploy):
  cd cloud_function && GCP_PROJECT=... GCS_BUCKET=... GCS_PREFIX=... \\
  BQ_STAGING_DATASET=staging BQ_METADATA_DATASET=metadata BQ_PROD_DATASET=prod \\
  python backfill.py

Or from repo root:
  cd cloud_function && python backfill.py
(with env vars exported or in .env)
"""

import logging
import re
import sys

from google.cloud import bigquery, storage

# Defer imports so config (and its required env vars) are only loaded when the
# script is run directly, not when this module is imported (e.g. by tests).
if __name__ == "__main__":
    from config import (
        ARCHIVE_SLIM_PREFIX,
        GCP_PROJECT,
        GCS_BUCKET,
        GCS_PREFIX,
        LOAD_MANIFEST_TABLE,
        MOST_POPULAR_SLIM_PREFIX,
    )
    from load_archive import load_archive
    from load_most_popular import load_most_popular

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
logger = logging.getLogger(__name__)


def get_loaded_paths() -> set[str]:
    """Query the load_manifest table to get already-loaded file paths."""
    client = bigquery.Client(project=GCP_PROJECT)
    query = f"""
    SELECT path
    FROM `{GCP_PROJECT}.{LOAD_MANIFEST_TABLE}`
    """
    logger.info("Fetching already-loaded paths from %s...", LOAD_MANIFEST_TABLE)
    result = client.query(query).result()
    loaded = {row.path for row in result}
    logger.info("Found %d already-loaded files", len(loaded))
    return loaded


def main() -> None:
    prefix = f"{GCS_PREFIX}/"
    archive_prefix = f"{GCS_PREFIX}/{ARCHIVE_SLIM_PREFIX}"
    most_popular_prefix = f"{GCS_PREFIX}/{MOST_POPULAR_SLIM_PREFIX}"

    # Get already-loaded paths from BigQuery
    loaded_paths = get_loaded_paths()

    client = storage.Client()
    bucket = client.bucket(GCS_BUCKET)

    archive_count = 0
    archive_skipped = 0
    most_popular_count = 0
    most_popular_skipped = 0
    errors = 0

    # List all blobs under the prefix (both archive_slim and most_popular_slim)
    blobs = bucket.list_blobs(prefix=prefix)
    for blob in blobs:
        name = blob.name
        if not name.endswith(".ndjson"):
            continue

        # Skip if already loaded
        if name in loaded_paths:
            if name.startswith(archive_prefix):
                archive_skipped += 1
            elif name.startswith(most_popular_prefix):
                most_popular_skipped += 1
            continue

        if name.startswith(archive_prefix):
            try:
                logger.info("Loading archive: %s", name)
                load_archive(GCS_BUCKET, name)
                archive_count += 1
            except Exception as e:
                logger.exception("Failed to load archive %s: %s", name, e)
                errors += 1
        elif name.startswith(most_popular_prefix):
            match = re.search(r"most_popular_slim/(\d{4}-\d{2}-\d{2})/", name)
            if not match:
                logger.warning("Skipping (no snapshot_date): %s", name)
                continue
            snapshot_date = match.group(1)
            try:
                logger.info("Loading most_popular: %s (snapshot_date=%s)", name, snapshot_date)
                load_most_popular(GCS_BUCKET, name, snapshot_date)
                most_popular_count += 1
            except Exception as e:
                logger.exception("Failed to load most_popular %s: %s", name, e)
                errors += 1

    logger.info(
        "Backfill complete: archive_slim=%d (skipped=%d), "
        "most_popular_slim=%d (skipped=%d), errors=%d",
        archive_count,
        archive_skipped,
        most_popular_count,
        most_popular_skipped,
        errors,
    )
    if errors:
        sys.exit(1)


if __name__ == "__main__":
    main()
