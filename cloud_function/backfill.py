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

from google.cloud import storage

# Ensure cloud_function is on path when run from repo root
if __name__ == "__main__":
    from config import (
        ARCHIVE_SLIM_PREFIX,
        GCS_BUCKET,
        GCS_PREFIX,
        MOST_POPULAR_SLIM_PREFIX,
    )
    from load_archive import load_archive
    from load_most_popular import load_most_popular

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
logger = logging.getLogger(__name__)


def main() -> None:
    prefix = f"{GCS_PREFIX}/"
    archive_prefix = f"{GCS_PREFIX}/{ARCHIVE_SLIM_PREFIX}"
    most_popular_prefix = f"{GCS_PREFIX}/{MOST_POPULAR_SLIM_PREFIX}"

    client = storage.Client()
    bucket = client.bucket(GCS_BUCKET)

    archive_count = 0
    most_popular_count = 0
    errors = 0

    # List all blobs under the prefix (both archive_slim and most_popular_slim)
    blobs = bucket.list_blobs(prefix=prefix)
    for blob in blobs:
        name = blob.name
        if not name.endswith(".ndjson"):
            continue
        if name.startswith(archive_prefix):
            try:
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
                load_most_popular(GCS_BUCKET, name, snapshot_date)
                most_popular_count += 1
            except Exception as e:
                logger.exception("Failed to load most_popular %s: %s", name, e)
                errors += 1

    logger.info(
        "Backfill complete: archive_slim=%d, most_popular_slim=%d, errors=%d",
        archive_count,
        most_popular_count,
        errors,
    )
    if errors:
        sys.exit(1)


if __name__ == "__main__":
    main()
