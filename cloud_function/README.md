# Cloud Function – GCS → BigQuery loader

Gen2 Cloud Function (`nyt-bq-loader`) triggered by Eventarc on every GCS
`object.finalize` event in the ingest bucket. It routes the new file to
the right loader, MERGEs into the prod table, and records the load in a
manifest table.

## Files

| File | Role |
|---|---|
| `main.py` | Entrypoint. Receives the Cloud Event, filters by GCS path prefix, dispatches to a loader. |
| `config.py` | Reads required env vars (no defaults — fails fast). |
| `load_archive.py` | Archive loader: temp table → DATE cast → staging → MERGE → manifest. |
| `load_most_popular.py` | Most Popular loader: injects `snapshot_date` from the GCS path. |
| `load_best_sellers.py` | Best Sellers loader: parses `published_date` STRING → DATE on insert. |
| `requirements.txt` | Function-only deps (slim — pinned to BigQuery + functions-framework). |
| `schema/` | **Auto-populated at deploy time** by `infra/deploy.sh`; `.gitignore`d. |

## Dispatch

`main.py` strips `GCS_PREFIX` from the object path and matches on a slim
folder name:

| Path prefix | Loader | Dedup key |
|---|---|---|
| `archive_slim/` | `load_archive` | `article_id` |
| `most_popular_slim/YYYY-MM-DD/` | `load_most_popular` (snapshot_date from path) | `(snapshot_date, id)` |
| `books_slim/YYYY-MM-DD/` | `load_best_sellers` | `(published_date, list_name_encoded, rank, list_updated)` |

Anything else is logged and ignored.

## Load pattern (all three loaders share this shape)

1. **Manifest check.** Skip if `metadata.load_manifest` already has a row
   for this `(source, path)`.
2. **Temp table.** Create a per-load temp table with a permissive schema
   (e.g. `pub_date` / `published_date` as STRING so raw ISO strings load).
3. **Load to temp.** `LoadJob` from GCS NDJSON → temp table (truncate).
4. **INSERT to staging.** Cast date columns to DATE, inject the
   `snapshot_date` (Most Popular only), then INSERT into the persistent
   staging table.
5. **Drop temp.** Keep the staging dataset clean.
6. **MERGE to prod.** `WHEN NOT MATCHED THEN INSERT ROW` — append-only,
   idempotent against re-loads of the same row.
7. **Manifest insert.** Record `(source, path, loaded_at)`.
8. **TRUNCATE staging.** Staging tables are transient.

This gives us idempotency at two layers: the manifest short-circuits
duplicate events, and the `MERGE … WHEN NOT MATCHED` is safe even if the
manifest check is bypassed.

## Configuration

Set via `--set-env-vars` during deploy (see [`infra/`](../infra/README.md)).
All are required.

| Variable | Example |
|---|---|
| `GCP_PROJECT` | `times-api-ingest` |
| `GCS_BUCKET` | `my-nyt-data` |
| `GCS_PREFIX` | `nyt-ingest` |
| `BQ_STAGING_DATASET` | `staging` |
| `BQ_METADATA_DATASET` | `metadata` |
| `BQ_PROD_DATASET` | `prod` |

## BigQuery tables it talks to

| Dataset | Table | Notes |
|---|---|---|
| `staging` | `archive_articles`, `most_popular_articles`, `best_sellers` | Transient. Truncated after each load. |
| `metadata` | `load_manifest` | `(source, path, loaded_at)`. Idempotency + audit. |
| `prod` | `archive_articles` | Partitioned MONTHLY by `pub_date`, clustered by `pub_date, section_name, news_desk`. |
| `prod` | `most_popular_articles` | Partitioned daily by `snapshot_date`. |
| `prod` | `best_sellers` | Partitioned MONTHLY by `published_date`, clustered by `list_name_encoded, published_date`. |

## Required IAM

The function's service account needs:

- **BigQuery Data Editor** on the three datasets (staging, metadata, prod)
- **BigQuery Job User** at project level
- **Storage Object Viewer** on the GCS bucket

## Deployment

`infra/deploy.sh` copies `schema/*.json` from the repo root into
`cloud_function/schema/` (which is `.gitignore`d) and runs `gcloud
functions deploy`. `.github/workflows/deploy-function.yml` triggers
automatically when `cloud_function/**`, `infra/deploy.sh`, or `schema/**`
change on `main`. See [`infra/README.md`](../infra/README.md) for the
full deploy contract.
