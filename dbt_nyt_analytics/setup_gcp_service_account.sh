#!/bin/bash
# Setup script for dbt service account in GCP
# Run this once to create and configure the service account

set -e

PROJECT_ID="times-api-ingest"
SA_NAME="dbt-runner"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
KEY_FILE="$HOME/.dbt/${SA_NAME}-key.json"

echo "Creating service account..."
gcloud iam service-accounts create ${SA_NAME} \
    --project=${PROJECT_ID} \
    --description="Service account for dbt transformations" \
    --display-name="dbt Runner"

echo ""
echo "Granting BigQuery permissions..."

# BigQuery Job User (project-level) - needed to run queries
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/bigquery.jobUser"

# Create datasets if they don't exist
echo ""
echo "Creating dbt datasets (if they don't exist)..."
bq mk --dataset --location=US ${PROJECT_ID}:dbt_staging 2>/dev/null || echo "dbt_staging already exists"
bq mk --dataset --location=US ${PROJECT_ID}:dbt_core 2>/dev/null || echo "dbt_core already exists"
bq mk --dataset --location=US ${PROJECT_ID}:dbt_analytics 2>/dev/null || echo "dbt_analytics already exists"
bq mk --dataset --location=US ${PROJECT_ID}:dev_dbt_staging 2>/dev/null || echo "dev_dbt_staging already exists"
bq mk --dataset --location=US ${PROJECT_ID}:dev_dbt_core 2>/dev/null || echo "dev_dbt_core already exists"
bq mk --dataset --location=US ${PROJECT_ID}:dev_dbt_analytics 2>/dev/null || echo "dev_dbt_analytics already exists"

# Grant dataset-level permissions
echo ""
echo "Granting dataset permissions..."

for dataset in dbt_staging dbt_core dbt_analytics dev_dbt_staging dev_dbt_core dev_dbt_analytics; do
    echo "  - ${dataset}"
    bq add-iam-policy-binding \
        --member="serviceAccount:${SA_EMAIL}" \
        --role="roles/bigquery.dataEditor" \
        ${PROJECT_ID}:${dataset}
done

# Create and download key
echo ""
echo "Creating service account key..."
mkdir -p ~/.dbt
gcloud iam service-accounts keys create ${KEY_FILE} \
    --iam-account=${SA_EMAIL} \
    --project=${PROJECT_ID}

echo ""
echo "✅ Setup complete!"
echo ""
echo "Service Account: ${SA_EMAIL}"
echo "Key saved to: ${KEY_FILE}"
echo ""
echo "Next steps:"
echo "1. Copy profiles.yml.example to ~/.dbt/profiles.yml"
echo "2. Update keyfile path in ~/.dbt/profiles.yml to: ${KEY_FILE}"
echo "3. Run: dbt debug"
