"""
Configuration for the NYT BigQuery loader Cloud Function.

Reads from environment variables (no defaults - fails if not set).
"""

import os

# GCS configuration
GCS_BUCKET = os.environ["GCS_BUCKET"]
GCS_PREFIX = os.environ["GCS_PREFIX"]

# BigQuery configuration (three datasets: staging, metadata, prod)
GCP_PROJECT = os.environ["GCP_PROJECT"]
BQ_STAGING_DATASET = os.environ["BQ_STAGING_DATASET"]
BQ_METADATA_DATASET = os.environ["BQ_METADATA_DATASET"]
BQ_PROD_DATASET = os.environ["BQ_PROD_DATASET"]

# Table names (same names in staging and prod, differentiated by dataset)
ARCHIVE_STAGING_TABLE = f"{BQ_STAGING_DATASET}.archive_articles"
ARCHIVE_FINAL_TABLE = f"{BQ_PROD_DATASET}.archive_articles"
MOST_POPULAR_STAGING_TABLE = f"{BQ_STAGING_DATASET}.most_popular_articles"
MOST_POPULAR_FINAL_TABLE = f"{BQ_PROD_DATASET}.most_popular_articles"
LOAD_MANIFEST_TABLE = f"{BQ_METADATA_DATASET}.load_manifest"

# Path prefixes for filtering
ARCHIVE_SLIM_PREFIX = "archive_slim/"
MOST_POPULAR_SLIM_PREFIX = "most_popular_slim/"
