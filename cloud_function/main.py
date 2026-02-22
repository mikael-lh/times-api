"""
Cloud Function entrypoint for GCS-to-BigQuery loader.

Receives Cloud Events from Eventarc (GCS object.finalize), filters by path,
and dispatches to archive or most_popular loader.
"""

import logging
import re
from typing import Any

import functions_framework
from cloudevents.http import CloudEvent

from config import ARCHIVE_SLIM_PREFIX, GCS_PREFIX, MOST_POPULAR_SLIM_PREFIX
from load_archive import load_archive
from load_most_popular import load_most_popular

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@functions_framework.cloud_event
def gcs_to_bigquery(cloud_event: CloudEvent) -> tuple[str, int]:
    """
    Handle GCS object finalize events and load to BigQuery.

    Args:
        cloud_event: Cloud Event with GCS object data

    Returns:
        Tuple of (message, status_code)
    """
    try:
        data = cloud_event.get_data()
        bucket = data.get("bucket")
        name = data.get("name")

        if not bucket or not name:
            logger.error("Missing bucket or name in event data")
            return "Missing bucket or name", 400

        logger.info(f"Received event for gs://{bucket}/{name}")

        # Remove prefix if present
        object_path = name
        if object_path.startswith(GCS_PREFIX + "/"):
            object_path = object_path[len(GCS_PREFIX) + 1 :]
        elif object_path.startswith(GCS_PREFIX):
            object_path = object_path[len(GCS_PREFIX) :]

        # Filter: only process archive_slim or most_popular_slim
        if object_path.startswith(ARCHIVE_SLIM_PREFIX):
            logger.info(f"Processing archive file: {name}")
            load_archive(bucket, name)
            return "Archive loaded successfully", 200

        elif object_path.startswith(MOST_POPULAR_SLIM_PREFIX):
            # Extract snapshot_date from path (e.g. most_popular_slim/2026-02-19/viewed_30.ndjson)
            match = re.search(
                r"most_popular_slim/(\d{4}-\d{2}-\d{2})/", object_path
            )
            if not match:
                logger.error(f"Could not extract snapshot_date from path: {name}")
                return "Invalid most_popular path format", 400

            snapshot_date = match.group(1)
            logger.info(
                f"Processing most_popular file: {name} (snapshot_date={snapshot_date})"
            )
            load_most_popular(bucket, name, snapshot_date)
            return "Most popular loaded successfully", 200

        else:
            logger.info(f"Ignoring non-slim file: {name}")
            return "File ignored (not a slim file)", 200

    except Exception as e:
        logger.exception(f"Error processing event: {e}")
        return f"Error: {str(e)}", 500
