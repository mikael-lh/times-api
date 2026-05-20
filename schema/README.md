# BigQuery schemas

Single source of truth for the BigQuery table schemas. Both
`infra/create_bq_tables.sh` (one-time setup) and `infra/deploy.sh`
(Cloud Function deploy) read from this folder.

| File | Used by |
|---|---|
| `archive_articles.json` | `staging.archive_articles`, `prod.archive_articles`, Cloud Function loader |
| `most_popular_articles.json` | `staging.most_popular_articles`, `prod.most_popular_articles`, Cloud Function loader |
| `best_sellers.json` | `staging.best_sellers`, `prod.best_sellers`, Cloud Function loader |

`infra/deploy.sh` copies these files into `cloud_function/schema/` at
deploy time (the destination is `.gitignore`d).

## Editing rules

- Add a column → update the JSON here, then re-run
  `create_bq_tables.sh` and re-deploy the Cloud Function. Existing
  tables won't auto-pick up new columns; use `bq update` or the
  console to alter them.
- Column names must match the slim NDJSON keys produced by the
  matching `*/transform.py`.
- `BigQuery` does not accept empty objects, so use `None` (not `{}`)
  for nullable `RECORD`/`JSON` fields in slim output.

dbt source columns are documented separately in
[`dbt_nyt_analytics/docs/column_descriptions.md`](../dbt_nyt_analytics/docs/column_descriptions.md);
the column names mirror these JSON schemas.
