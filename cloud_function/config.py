"""
Configuration for the NYT BigQuery loader Cloud Function.

Reads from environment variables; defaults match the workflow setup.
"""

import os

# GCS configuration
GCS_BUCKET = os.getenv("GCS_BUCKET", "nyt-ingest")
GCS_PREFIX = os.getenv("GCS_PREFIX", "nyt-ingest")

# BigQuery configuration
GCP_PROJECT = os.getenv("GCP_PROJECT", "")
BQ_DATASET = os.getenv("BQ_DATASET", "nyt")

# Table names
ARCHIVE_STAGING_TABLE = f"{BQ_DATASET}.archive_staging"
ARCHIVE_FINAL_TABLE = f"{BQ_DATASET}.archive_articles"
MOST_POPULAR_STAGING_TABLE = f"{BQ_DATASET}.most_popular_staging"
MOST_POPULAR_FINAL_TABLE = f"{BQ_DATASET}.most_popular_articles"
LOAD_MANIFEST_TABLE = f"{BQ_DATASET}.load_manifest"

# Path prefixes for filtering
ARCHIVE_SLIM_PREFIX = "archive_slim/"
MOST_POPULAR_SLIM_PREFIX = "most_popular_slim/"
