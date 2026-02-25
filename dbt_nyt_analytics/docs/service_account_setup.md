# dbt Service Account Setup

This guide explains how to set up the GCP service account for dbt.

## Quick Setup

Run the setup script (requires `gcloud` and `bq` CLI tools):

```bash
cd dbt_nyt_analytics
chmod +x setup_gcp_service_account.sh
./setup_gcp_service_account.sh
```

This will:
1. Create a service account: `dbt-runner@times-api-ingest.iam.gserviceaccount.com`
2. Grant necessary BigQuery permissions
3. Create all required datasets (dev and prod)
4. Generate a service account key at `~/.dbt/dbt-runner-key.json`

Then copy and configure your profile:

```bash
cp profiles.yml.example ~/.dbt/profiles.yml
# Key path is already set correctly if you used the setup script
```

Test the connection:

```bash
dbt debug              # Tests dev (oauth)
dbt debug --target prod  # Tests prod (service account)
```

---

## Dataset Structure

With the `generate_schema_name` macro, models are separated by target:

| Target | Staging | Core | Analytics |
|--------|---------|------|-----------|
| **dev** | `dev_dbt_staging` | `dev_dbt_core` | `dev_dbt_analytics` |
| **prod** | `dbt_staging` | `dbt_core` | `dbt_analytics` |

This prevents dev work from overwriting production tables.

---

## Manual Setup (if script fails)

### 1. Create Service Account

```bash
gcloud iam service-accounts create dbt-runner \
    --project=times-api-ingest \
    --description="Service account for dbt transformations" \
    --display-name="dbt Runner"
```

### 2. Grant Permissions

```bash
# BigQuery Job User (run queries)
gcloud projects add-iam-policy-binding times-api-ingest \
    --member="serviceAccount:dbt-runner@times-api-ingest.iam.gserviceaccount.com" \
    --role="roles/bigquery.jobUser"
```

### 3. Create Datasets

```bash
bq mk --dataset --location=US times-api-ingest:dbt_staging
bq mk --dataset --location=US times-api-ingest:dbt_core
bq mk --dataset --location=US times-api-ingest:dbt_analytics
bq mk --dataset --location=US times-api-ingest:dev_dbt_staging
bq mk --dataset --location=US times-api-ingest:dev_dbt_core
bq mk --dataset --location=US times-api-ingest:dev_dbt_analytics
```

### 4. Grant Dataset Permissions

```bash
for dataset in dbt_staging dbt_core dbt_analytics dev_dbt_staging dev_dbt_core dev_dbt_analytics; do
    bq add-iam-policy-binding \
        --member="serviceAccount:dbt-runner@times-api-ingest.iam.gserviceaccount.com" \
        --role="roles/bigquery.dataEditor" \
        times-api-ingest:${dataset}
done
```

### 5. Create Key

```bash
mkdir -p ~/.dbt
gcloud iam service-accounts keys create ~/.dbt/dbt-runner-key.json \
    --iam-account=dbt-runner@times-api-ingest.iam.gserviceaccount.com \
    --project=times-api-ingest
```

---

## GitHub Actions Setup

Add the service account key as a GitHub secret:

1. Copy the key contents:
   ```bash
   cat ~/.dbt/dbt-runner-key.json | pbcopy  # macOS
   cat ~/.dbt/dbt-runner-key.json | xclip   # Linux
   ```

2. Go to GitHub: **Settings → Secrets and variables → Actions**

3. Add new secret:
   - Name: `GCP_SA_KEY`
   - Value: Paste the JSON key

The GitHub Actions workflow will use this for automated runs.

---

## Permissions Summary

| Permission | Scope | Purpose |
|------------|-------|---------|
| `bigquery.jobUser` | Project-level | Run queries and dbt jobs |
| `bigquery.dataEditor` | 6 datasets | Create/update tables in dev and prod datasets |

---

## Troubleshooting

**Error: "Permission denied"**
- Verify SA has `bigquery.jobUser` at project level
- Verify SA has `bigquery.dataEditor` on each dataset

**Error: "Dataset not found"**
- Create the dataset with `bq mk`
- Ensure location is `US` (matches source data)

**Error: "Key file not found"**
- Check path in `~/.dbt/profiles.yml`
- Ensure key was created: `ls -la ~/.dbt/dbt-runner-key.json`
