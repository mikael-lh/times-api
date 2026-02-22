#!/usr/bin/env bash
set -euo pipefail

# One-time BigQuery setup: create dataset and tables for NYT pipeline
# Run once per GCP project before deploying the Cloud Function

# Configuration from environment
GCP_PROJECT="${GCP_PROJECT:-}"
BQ_DATASET="${BQ_DATASET:-nyt}"
SCHEMA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../schema" && pwd)"

if [[ -z "$GCP_PROJECT" ]]; then
  echo "Error: GCP_PROJECT environment variable must be set"
  echo "Usage: GCP_PROJECT=your-project BQ_DATASET=nyt ./infra/create_bq_tables.sh"
  exit 1
fi

echo "Creating BigQuery dataset and tables for NYT pipeline..."
echo "  Project: $GCP_PROJECT"
echo "  Dataset: $BQ_DATASET"
echo "  Schema dir: $SCHEMA_DIR"
echo ""

# Create dataset if it doesn't exist
echo "Creating dataset $BQ_DATASET (if it doesn't exist)..."
bq --project_id="$GCP_PROJECT" mk --dataset \
  --description="NYT Archive and Most Popular articles" \
  --location=US \
  "$BQ_DATASET" 2>/dev/null || echo "  (Dataset already exists)"

# Create archive_staging (no partitioning, temporary staging table)
echo "Creating table $BQ_DATASET.archive_staging..."
bq --project_id="$GCP_PROJECT" mk --table \
  --description="Staging table for archive articles (truncated after each load)" \
  "$BQ_DATASET.archive_staging" \
  "$SCHEMA_DIR/archive_articles.json" 2>/dev/null || echo "  (Table already exists)"

# Create archive_articles (partitioned by pub_date)
echo "Creating table $BQ_DATASET.archive_articles (partitioned by pub_date)..."
bq --project_id="$GCP_PROJECT" mk --table \
  --description="Final archive articles table" \
  --time_partitioning_field=pub_date \
  --time_partitioning_type=DAY \
  "$BQ_DATASET.archive_articles" \
  "$SCHEMA_DIR/archive_articles.json" 2>/dev/null || echo "  (Table already exists)"

# Create most_popular_staging (no partitioning, temporary staging table)
echo "Creating table $BQ_DATASET.most_popular_staging..."
bq --project_id="$GCP_PROJECT" mk --table \
  --description="Staging table for most popular articles (truncated after each load)" \
  "$BQ_DATASET.most_popular_staging" \
  "$SCHEMA_DIR/most_popular_articles.json" 2>/dev/null || echo "  (Table already exists)"

# Create most_popular_articles (partitioned by snapshot_date)
echo "Creating table $BQ_DATASET.most_popular_articles (partitioned by snapshot_date)..."
bq --project_id="$GCP_PROJECT" mk --table \
  --description="Final most popular articles table" \
  --time_partitioning_field=snapshot_date \
  --time_partitioning_type=DAY \
  "$BQ_DATASET.most_popular_articles" \
  "$SCHEMA_DIR/most_popular_articles.json" 2>/dev/null || echo "  (Table already exists)"

# Create load_manifest table
echo "Creating table $BQ_DATASET.load_manifest..."
bq --project_id="$GCP_PROJECT" mk --table \
  --description="Manifest of loaded files (for idempotency and audit)" \
  "$BQ_DATASET.load_manifest" \
  source:STRING,path:STRING,loaded_at:TIMESTAMP 2>/dev/null || echo "  (Table already exists)"

echo ""
echo "✅ BigQuery setup complete!"
echo "Tables created in $GCP_PROJECT.$BQ_DATASET:"
echo "  - archive_staging"
echo "  - archive_articles (partitioned by pub_date)"
echo "  - most_popular_staging"
echo "  - most_popular_articles (partitioned by snapshot_date)"
echo "  - load_manifest"
