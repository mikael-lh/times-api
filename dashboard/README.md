# NYT Archive Overview dashboard

Streamlit dashboard over the dbt models in BigQuery.

## Features

- **Time series** – articles published and average word count by month.
- **Breakdowns** – by section, news desk, and type of material.
- **Top lists** – top 10 keywords and authors by article count.
- **Filters** – date range, sections, news desks, material types,
  authors, keywords. All filters are interconnected and apply to every
  chart.
- Auto-excludes articles outside the 100-year window and zero word counts.

## Quickstart

```bash
# From the project root
uv sync --group dashboard

cd dashboard
cp .env.example .env
# Edit .env with your GCP project ID and credentials path

cd ..
uv run streamlit run dashboard/pages/1_📰_Archive_Overview.py
```

The Streamlit page launches at `http://localhost:8501`.

## Configuration (`dashboard/.env`)

| Var | Default | Notes |
|---|---|---|
| `GCP_PROJECT_ID` | `times-api-ingest` | Override for multi-project setups |
| `GCP_CREDENTIALS_PATH` | unset | Path to a service-account JSON key. If unset, falls back to application-default credentials (`gcloud auth application-default login`). |
| `DBT_CORE_DATASET` | `dbt_core` | Override when running against a non-prod target |
| `DBT_ANALYTICS_DATASET` | `dbt_analytics` |  |
| `DBT_STAGING_DATASET` | `dbt_staging` |  |

You can reuse the `dbt-runner` service account key for the dashboard or
create a separate read-only SA.

## Data sources

| Table | Used for |
|---|---|
| `dbt_core.fct_articles` | Main article fact table |
| `dbt_analytics.agg_author_performance` | Author metrics |
| `dbt_analytics.agg_keyword_trends` | Keyword trends |
| `dbt_staging.stg_archive_articles` | Staging table used to populate filter pickers |

## Related docs

- [`dbt_nyt_analytics/README.md`](../dbt_nyt_analytics/README.md) – the
  models behind every query.
- [`docs/dashboard_insights.md`](../docs/dashboard_insights.md) –
  brainstorm of additional dashboard concepts (not all implemented).
