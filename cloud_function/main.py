"""
Cloud Function entrypoint for GCS-to-BigQuery loader.

Receives Cloud Events from Eventarc (GCS object create via Audit Logs),
filters by GCS_PREFIX path, and dispatches to archive / most_popular /
best_sellers loaders.
"""

import logging
import re

import functions_framework
from cloudevents.http import CloudEvent
from config import (
    ARCHIVE_SLIM_PREFIX,
    BOOKS_SLIM_PREFIX,
    GCS_PREFIX,
    MOST_POPULAR_SLIM_PREFIX,
)
from event_paths import bucket_and_object_from_event_data, relative_object_path
from load_archive import load_archive
from load_best_sellers import load_best_sellers
from load_most_popular import load_most_popular

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@functions_framework.cloud_event
def gcs_to_bigquery(cloud_event: CloudEvent) -> tuple[str, int]:
    """
    Handle GCS object create events and load to BigQuery.

    Args:
        cloud_event: Cloud Event with GCS object or Audit Log data

    Returns:
        Tuple of (message, status_code)
    """
    try:
        data = cloud_event.get_data()
        bucket, name = bucket_and_object_from_event_data(data)

        if not bucket or not name:
            logger.error("Missing bucket or object name in event data")
            return "Missing bucket or name", 400

        logger.info(f"Received event for gs://{bucket}/{name}")

        object_path = relative_object_path(name, GCS_PREFIX)
        if object_path is None:
            logger.info(
                "Ignoring object outside GCS_PREFIX folder %s/: %s",
                GCS_PREFIX,
                name,
            )
            return "File ignored (outside GCS_PREFIX)", 200

        if object_path.startswith(ARCHIVE_SLIM_PREFIX):
            logger.info(f"Processing archive file: {name}")
            load_archive(bucket, name)
            return "Archive loaded successfully", 200

        if object_path.startswith(MOST_POPULAR_SLIM_PREFIX):
            # Extract snapshot_date from path (e.g. most_popular_slim/2026-02-19/viewed_30.ndjson)
            match = re.search(r"most_popular_slim/(\d{4}-\d{2}-\d{2})/", object_path)
            if not match:
                logger.error(f"Could not extract snapshot_date from path: {name}")
                return "Invalid most_popular path format", 400

            snapshot_date = match.group(1)
            logger.info(f"Processing most_popular file: {name} (snapshot_date={snapshot_date})")
            load_most_popular(bucket, name, snapshot_date)
            return "Most popular loaded successfully", 200

        if object_path.startswith(BOOKS_SLIM_PREFIX):
            logger.info(f"Processing best_sellers file: {name}")
            load_best_sellers(bucket, name)
            return "Best sellers loaded successfully", 200

        logger.info(f"Ignoring non-slim file: {name}")
        return "File ignored (not a slim file)", 200

    except Exception as e:
        logger.exception(f"Error processing event: {e}")
        return f"Error: {str(e)}", 500
