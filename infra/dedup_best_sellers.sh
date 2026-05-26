#!/usr/bin/env bash
# One-off cleanup: deduplicate prod.best_sellers after bulk-load race duplicates.
#
# Keeps one row per (published_date, list_name_encoded, rank, list_updated).
# Safe to re-run (no-op when already deduped).
#
# Usage:
#   GCP_PROJECT=times-api-ingest ./infra/dedup_best_sellers.sh

set -euo pipefail

GCP_PROJECT="${GCP_PROJECT:-}"
BQ_PROD_DATASET="${BQ_PROD_DATASET:-prod}"

if [[ -z "$GCP_PROJECT" ]]; then
  echo "Error: set GCP_PROJECT (e.g. GCP_PROJECT=times-api-ingest)" >&2
  exit 1
fi

echo "Deduplicating ${GCP_PROJECT}.${BQ_PROD_DATASET}.best_sellers ..."

bq query --use_legacy_sql=false "
CREATE OR REPLACE TABLE \`${GCP_PROJECT}.${BQ_PROD_DATASET}.best_sellers\`
PARTITION BY DATE_TRUNC(published_date, MONTH)
CLUSTER BY list_name_encoded, published_date
AS
SELECT * EXCEPT (rn)
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY published_date, list_name_encoded, rank, list_updated
            ORDER BY primary_isbn13, title
        ) AS rn
    FROM \`${GCP_PROJECT}.${BQ_PROD_DATASET}.best_sellers\`
)
WHERE rn = 1;
"

echo "Done. Row count:"
bq query --use_legacy_sql=false --format=csv \
  "SELECT COUNT(*) AS row_count FROM \`${GCP_PROJECT}.${BQ_PROD_DATASET}.best_sellers\`"
