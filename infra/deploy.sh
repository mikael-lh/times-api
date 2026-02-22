#!/usr/bin/env bash
set -euo pipefail

# Deploy NYT BigQuery loader Cloud Function (Gen2) with Eventarc trigger

# Configuration from environment
GCP_PROJECT="${GCP_PROJECT:-}"
GCS_BUCKET="${GCS_BUCKET:-nyt-ingest}"
GCS_PREFIX="${GCS_PREFIX:-nyt-ingest}"
BQ_DATASET="${BQ_DATASET:-nyt}"
FUNCTION_NAME="${FUNCTION_NAME:-nyt-bq-loader}"
REGION="${REGION:-us-central1}"
SERVICE_ACCOUNT="${SERVICE_ACCOUNT:-}"

if [[ -z "$GCP_PROJECT" ]]; then
  echo "Error: GCP_PROJECT environment variable must be set"
  echo "Usage: GCP_PROJECT=your-project GCS_BUCKET=bucket-name ./infra/deploy.sh"
  exit 1
fi

echo "Deploying Cloud Function: $FUNCTION_NAME"
echo "  Project: $GCP_PROJECT"
echo "  Region: $REGION"
echo "  Bucket: $GCS_BUCKET"
echo "  Prefix: $GCS_PREFIX"
echo "  Dataset: $BQ_DATASET"
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
  --set-env-vars="GCP_PROJECT=$GCP_PROJECT,GCS_BUCKET=$GCS_BUCKET,GCS_PREFIX=$GCS_PREFIX,BQ_DATASET=$BQ_DATASET"
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
