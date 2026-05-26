#!/usr/bin/env bash
set -euo pipefail

# One-time BigQuery setup: create dataset and tables for NYT pipeline
# Run once per GCP project before deploying the Cloud Function

# Configuration
GCP_PROJECT="${GCP_PROJECT:-}"
BQ_STAGING_DATASET="staging"
BQ_METADATA_DATASET="metadata"
BQ_PROD_DATASET="prod"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && git rev-parse --show-toplevel)"
SCHEMA_DIR="$REPO_ROOT/schema"

# Validate required variables
if [[ -z "$GCP_PROJECT" ]]; then
  echo "Error: GCP_PROJECT environment variable must be set"
  echo ""
  echo "Usage:"
  echo "  GCP_PROJECT=my-project ./infra/create_bq_tables.sh"
  echo ""
  echo "This will create three datasets: staging, metadata, prod"
  exit 1
fi

echo "Creating BigQuery datasets and tables for NYT pipeline..."
echo "  Project: $GCP_PROJECT"
echo "  Datasets: $BQ_STAGING_DATASET, $BQ_METADATA_DATASET, $BQ_PROD_DATASET"
echo "  Schema dir: $SCHEMA_DIR"
echo ""

# Create staging dataset
echo "Creating dataset $BQ_STAGING_DATASET (if it doesn't exist)..."
bq --project_id="$GCP_PROJECT" mk --dataset \
  --description="Staging tables for NYT load pipeline (truncated after each load)" \
  --location=US \
  "$BQ_STAGING_DATASET" 2>/dev/null || echo "  (Dataset already exists)"

# Create metadata dataset
echo "Creating dataset $BQ_METADATA_DATASET (if it doesn't exist)..."
bq --project_id="$GCP_PROJECT" mk --dataset \
  --description="Pipeline manifest and metadata for NYT load" \
  --location=US \
  "$BQ_METADATA_DATASET" 2>/dev/null || echo "  (Dataset already exists)"

# Create prod dataset
echo "Creating dataset $BQ_PROD_DATASET (if it doesn't exist)..."
bq --project_id="$GCP_PROJECT" mk --dataset \
  --description="Final NYT archive and most popular articles" \
  --location=US \
  "$BQ_PROD_DATASET" 2>/dev/null || echo "  (Dataset already exists)"

# Staging: archive_articles
echo "Creating table $BQ_STAGING_DATASET.archive_articles..."
bq --project_id="$GCP_PROJECT" mk --table \
  --description="Staging table for archive articles (truncated after each load)" \
  "$BQ_STAGING_DATASET.archive_articles" \
  "$SCHEMA_DIR/archive_articles.json" 2>/dev/null || echo "  (Table already exists)"

# Staging: most_popular_articles
echo "Creating table $BQ_STAGING_DATASET.most_popular_articles..."
bq --project_id="$GCP_PROJECT" mk --table \
  --description="Staging table for most popular articles (truncated after each load)" \
  "$BQ_STAGING_DATASET.most_popular_articles" \
  "$SCHEMA_DIR/most_popular_articles.json" 2>/dev/null || echo "  (Table already exists)"

# Staging: best_sellers
echo "Creating table $BQ_STAGING_DATASET.best_sellers..."
bq --project_id="$GCP_PROJECT" mk --table \
  --description="Staging table for Best Sellers list entries (truncated after each load)" \
  "$BQ_STAGING_DATASET.best_sellers" \
  "$SCHEMA_DIR/best_sellers.json" 2>/dev/null || echo "  (Table already exists)"

# Metadata: load_manifest
echo "Creating table $BQ_METADATA_DATASET.load_manifest..."
bq --project_id="$GCP_PROJECT" mk --table \
  --description="Manifest of loaded files (for idempotency and audit)" \
  "$BQ_METADATA_DATASET.load_manifest" \
  source:STRING,path:STRING,loaded_at:TIMESTAMP 2>/dev/null || echo "  (Table already exists)"

# Prod: archive_articles (partitioned by pub_date - MONTHLY to support 100+ years)
echo "Creating table $BQ_PROD_DATASET.archive_articles (partitioned by pub_date - MONTHLY)..."
bq --project_id="$GCP_PROJECT" mk --table \
  --description="Final archive articles table" \
  --time_partitioning_field=pub_date \
  --time_partitioning_type=MONTH \
  --clustering_fields=pub_date,section_name,news_desk \
  "$BQ_PROD_DATASET.archive_articles" \
  "$SCHEMA_DIR/archive_articles.json" 2>/dev/null || echo "  (Table already exists)"

# Prod: most_popular_articles (partitioned by snapshot_date)
echo "Creating table $BQ_PROD_DATASET.most_popular_articles (partitioned by snapshot_date)..."
bq --project_id="$GCP_PROJECT" mk --table \
  --description="Final most popular articles table" \
  --time_partitioning_field=snapshot_date \
  --time_partitioning_type=DAY \
  "$BQ_PROD_DATASET.most_popular_articles" \
  "$SCHEMA_DIR/most_popular_articles.json" 2>/dev/null || echo "  (Table already exists)"

# Prod: best_sellers (partitioned by published_date, clustered by list)
echo "Creating table $BQ_PROD_DATASET.best_sellers (partitioned by published_date, clustered by list_name_encoded)..."
bq --project_id="$GCP_PROJECT" mk --table \
  --description="Final NYT Best Sellers table (one row per published_date, list, rank, list_updated)" \
  --time_partitioning_field=published_date \
  --time_partitioning_type=MONTH \
  --clustering_fields=list_name_encoded,published_date \
  "$BQ_PROD_DATASET.best_sellers" \
  "$SCHEMA_DIR/best_sellers.json" 2>/dev/null || echo "  (Table already exists)"

echo ""
echo "✅ BigQuery setup complete!"
echo "Datasets and tables in $GCP_PROJECT:"
echo "  $BQ_STAGING_DATASET: archive_articles, most_popular_articles, best_sellers"
echo "  $BQ_METADATA_DATASET: load_manifest"
echo "  $BQ_PROD_DATASET: archive_articles (partitioned MONTHLY by pub_date, clustered), most_popular_articles (partitioned by snapshot_date), best_sellers (partitioned MONTHLY by published_date, clustered by list_name_encoded)"
