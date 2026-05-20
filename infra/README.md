# Infrastructure scripts

Shell scripts that provision and deploy the BigQuery side of the pipeline.

| Script | When to run | What it does |
|---|---|---|
| `create_bq_tables.sh` | Once per GCP project | Creates the `staging`, `metadata`, and `prod` datasets and all required tables from `schema/*.json`. Idempotent (`mk` skips existing). |
| `deploy.sh` | On every Cloud Function change | Copies `schema/*.json` into `cloud_function/schema/`, then `gcloud functions deploy` with all required env vars. |

Both scripts `set -euo pipefail` and exit non-zero with a clear message
if a required variable is missing.

## One-time BigQuery setup

```bash
GCP_PROJECT=your-project ./infra/create_bq_tables.sh
```

Creates:

- Dataset `staging` with `archive_articles`, `most_popular_articles`, `best_sellers` (transient; truncated after each load).
- Dataset `metadata` with `load_manifest(source, path, loaded_at)`.
- Dataset `prod` with the three final tables, partitioned and clustered as documented in [`cloud_function/README.md`](../cloud_function/README.md).

Dataset names are hardcoded in the script (`staging`, `metadata`, `prod`).
If you need different names, edit the constants at the top and keep them
in sync with the Cloud Function env vars below.

## Deploying the Cloud Function

`deploy.sh` is invoked automatically by
[`.github/workflows/deploy-function.yml`](../.github/workflows/deploy-function.yml)
on every push to `main` that touches `cloud_function/**`, `infra/deploy.sh`,
or `schema/**`. To deploy manually:

```bash
GCP_PROJECT=your-project \
GCS_BUCKET=your-bucket \
GCS_PREFIX=nyt-ingest \
BQ_STAGING_DATASET=staging \
BQ_METADATA_DATASET=metadata \
BQ_PROD_DATASET=prod \
FUNCTION_NAME=nyt-bq-loader \
REGION=europe-west1 \
./infra/deploy.sh
```

`REGION` must match the GCS bucket region for the Eventarc trigger.
`SERVICE_ACCOUNT` is optional; if set, the function runs as that SA.

### Required GitHub Actions variables

The deploy workflow reads them as `vars.*`:

| Variable | Example |
|---|---|
| `GCP_PROJECT` | `times-api-ingest` |
| `GCS_BUCKET` | `my-nyt-data` |
| `GCS_PREFIX` | `nyt-ingest` |
| `BQ_STAGING_DATASET` | `staging` |
| `BQ_METADATA_DATASET` | `metadata` |
| `BQ_PROD_DATASET` | `prod` |
| `REGION` | `europe-west1` |
| `FUNCTION_NAME` | `nyt-bq-loader` |

Plus the `GCP_SA_KEY_DEPLOY` secret (a service account with Cloud
Functions deployment permissions).

## Service accounts at a glance

| Account | Used by | Roles |
|---|---|---|
| Ingest SA (`GCP_SA_KEY_INGEST`) | Daily/weekly/archive ingest workflows | Storage Object Admin (or Storage Object Creator) on the bucket |
| Deploy SA (`GCP_SA_KEY_DEPLOY`) | `deploy-function.yml` | Cloud Functions Admin + roles needed to bind Eventarc |
| Runtime SA (function default or `SERVICE_ACCOUNT`) | The Cloud Function itself | BigQuery Job User (project), BigQuery Data Editor (staging/metadata/prod), Storage Object Viewer (bucket) |
| dbt SA (`GCP_SA_KEY`) | `dbt-run.yml`, `dbt-pr.yml` | BigQuery Job User + BigQuery Data Editor on dbt-managed datasets |

## Schema is the source of truth

Both scripts pull from the top-level [`schema/`](../schema/README.md)
folder. Update a column there, and the next `create_bq_tables.sh` /
`deploy.sh` run picks it up.
