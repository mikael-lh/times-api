#!/usr/bin/env bash
set -euo pipefail

# Deploy NYT BigQuery loader Cloud Function (Gen2) with Eventarc trigger

# Configuration from environment (no defaults - fail fast if not set)
GCP_PROJECT="${GCP_PROJECT:-}"
GCS_BUCKET="${GCS_BUCKET:-}"
GCS_PREFIX="${GCS_PREFIX:-}"
BQ_STAGING_DATASET="${BQ_STAGING_DATASET:-}"
BQ_METADATA_DATASET="${BQ_METADATA_DATASET:-}"
BQ_PROD_DATASET="${BQ_PROD_DATASET:-}"
FUNCTION_NAME="${FUNCTION_NAME:-}"
REGION="${REGION:-}"
SERVICE_ACCOUNT="${SERVICE_ACCOUNT:-}"

# Validate required variables
REQUIRED_VARS=(
  "GCP_PROJECT"
  "GCS_BUCKET"
  "GCS_PREFIX"
  "BQ_STAGING_DATASET"
  "BQ_METADATA_DATASET"
  "BQ_PROD_DATASET"
  "FUNCTION_NAME"
  "REGION"
)

MISSING_VARS=()
for var in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!var}" ]]; then
    MISSING_VARS+=("$var")
  fi
done

if [[ ${#MISSING_VARS[@]} -gt 0 ]]; then
  echo "Error: Required environment variables not set:"
  for var in "${MISSING_VARS[@]}"; do
    echo "  - $var"
  done
  echo ""
  echo "Usage example:"
  echo "  GCP_PROJECT=my-project GCS_BUCKET=my-bucket GCS_PREFIX=nyt-ingest \\"
  echo "  BQ_STAGING_DATASET=staging BQ_METADATA_DATASET=metadata BQ_PROD_DATASET=prod \\"
  echo "  FUNCTION_NAME=nyt-bq-loader REGION=europe-west1 \\"
  echo "  ./infra/deploy.sh"
  exit 1
fi

echo "Deploying Cloud Function: $FUNCTION_NAME"
echo "  Project: $GCP_PROJECT"
echo "  Region: $REGION"
echo "  Bucket: $GCS_BUCKET"
echo "  Prefix: $GCS_PREFIX"
echo "  Datasets: $BQ_STAGING_DATASET, $BQ_METADATA_DATASET, $BQ_PROD_DATASET"
echo ""

# Copy schema files to cloud_function/schema/ for deployment
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && git rev-parse --show-toplevel)"
echo "Copying schema files to cloud_function/schema/..."
mkdir -p "$REPO_ROOT/cloud_function/schema"
cp "$REPO_ROOT/schema"/*.json "$REPO_ROOT/cloud_function/schema/"
echo "✓ Schema files copied"
echo ""

# Build gcloud command
DEPLOY_CMD=(
  gcloud functions deploy "$FUNCTION_NAME"
  --gen2
  --runtime=python312
  --region="$REGION"
  --source="./cloud_function"
  --entry-point=gcs_to_bigquery
  --trigger-event-filters="type=google.cloud.storage.object.v1.finalized"
  --trigger-event-filters="bucket=$GCS_BUCKET"
  --set-env-vars="GCP_PROJECT=$GCP_PROJECT,GCS_BUCKET=$GCS_BUCKET,GCS_PREFIX=$GCS_PREFIX,BQ_STAGING_DATASET=$BQ_STAGING_DATASET,BQ_METADATA_DATASET=$BQ_METADATA_DATASET,BQ_PROD_DATASET=$BQ_PROD_DATASET"
  --project="$GCP_PROJECT"
  --max-instances=10
  --timeout=540s
  --memory=512MB
)

# Add service account if specified
if [[ -n "$SERVICE_ACCOUNT" ]]; then
  DEPLOY_CMD+=(--service-account="$SERVICE_ACCOUNT")
fi

# Deploy
echo "Running: ${DEPLOY_CMD[*]}"
"${DEPLOY_CMD[@]}"

echo ""
echo "✅ Cloud Function deployed successfully!"
echo "Function: $FUNCTION_NAME"
echo "Trigger: GCS bucket $GCS_BUCKET (object.finalize)"
echo ""
echo "The function will process files matching:"
echo "  - archive_slim/*.ndjson"
echo "  - most_popular_slim/*/*.ndjson"
