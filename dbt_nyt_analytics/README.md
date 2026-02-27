# NYT Analytics dbt Project

This dbt project transforms raw NYT article data from BigQuery into analytics-ready models.

## Quick Start

### 1. Install dbt

```bash
pip install dbt-bigquery
# Or with uv: uv add --group dbt dbt-bigquery
```

### 2. Set up GCP Service Account

Run the setup script to create the service account and configure permissions:

```bash
cd dbt_nyt_analytics
./setup_gcp_service_account.sh
```

This creates:
- Service account: `dbt-runner@times-api-ingest.iam.gserviceaccount.com`
- Key file: `~/.dbt/dbt-runner-key.json`
- All required BigQuery datasets (dev and prod)

See [`docs/service_account_setup.md`](docs/service_account_setup.md) for manual setup or troubleshooting.

### 3. Configure dbt Profile

```bash
cp profiles.yml.example ~/.dbt/profiles.yml
# Key path is already correct if you used the setup script
```

### 4. Test Connection

```bash
dbt debug              # Test dev connection (uses oauth)
dbt debug --target prod  # Test prod connection (uses service account)
```

### 5. Install Packages & Run

```bash
dbt deps               # Install dbt_utils package
dbt run                # Build all models (dev target)
dbt test               # Run data quality tests
```

---

## Project Structure

```
models/
├── staging/          # Clean and standardize source data
├── intermediate/     # Flatten nested structures (ephemeral)
└── marts/
    ├── core/         # Fact and dimension tables
    └── analytics/    # Aggregated metrics tables
```

## Models Overview

### Staging Layer
- `stg_archive_articles` - Cleaned archive articles (incremental)
- `stg_most_popular_articles` - Cleaned most popular snapshots (incremental)

### Intermediate Layer (Ephemeral)
- `int_keywords_flattened` - One row per article-keyword
- `int_authors_flattened` - One row per article-author

### Core Marts
- `fct_articles` - Main fact table with article metrics
- `fct_article_popularity` - Popularity tracking over time
- `dim_authors` - Author dimension
- `dim_keywords` - Keyword dimension
- `dim_sections` - Section/news desk dimension

### Analytics Marts
- `agg_articles_by_month` - Monthly content trends
- `agg_author_performance` - Author productivity metrics
- `agg_section_trends` - Section trends by year
- `agg_keyword_trends` - Keyword/topic trends by year

---

## Dev vs Prod Separation

The project uses a custom `generate_schema_name` macro to automatically separate dev and prod datasets:

| Target | Command | Staging | Core | Analytics |
|--------|---------|---------|------|-----------|
| **Dev** | `dbt run` | `dev_dbt_staging` | `dev_dbt_core` | `dev_dbt_analytics` |
| **Prod** | `dbt run --target prod` | `dbt_staging` | `dbt_core` | `dbt_analytics` |

This prevents development work from overwriting production tables.

---

## Running Models

```bash
# Run all models (dev)
dbt run

# Run all models (prod)
dbt run --target prod

# Run specific model and its dependencies
dbt run --select +fct_articles

# Full refresh (rebuild incremental tables)
dbt run --full-refresh

# Run tests
dbt test

# Run specific test
dbt test --select stg_archive_articles

# Generate docs
dbt docs generate
dbt docs serve
```

---

## Datasets Created

Based on target:

### Dev Target
| Dataset | Description |
|---------|-------------|
| `dev_dbt_staging` | Staging layer views |
| `dev_dbt_core` | Fact and dimension tables |
| `dev_dbt_analytics` | Aggregated analytics tables |

### Prod Target
| Dataset | Description |
|---------|-------------|
| `dbt_staging` | Staging layer views |
| `dbt_core` | Fact and dimension tables |
| `dbt_analytics` | Aggregated analytics tables |

---

## CI/CD

The project runs automatically via GitHub Actions:
- **Schedule**: Daily at 8:00 UTC (after ingestion completes at 6:00 UTC)
- **Manual**: Can be triggered with optional `--full-refresh` and `--select` flags
- **Target**: Runs with `--target prod` in CI

See [`.github/workflows/dbt-run.yml`](../.github/workflows/dbt-run.yml) for details.

To enable GitHub Actions:
1. Ensure service account is created (run setup script)
2. Add `GCP_SA_KEY` secret to GitHub (contents of `~/.dbt/dbt-runner-key.json`)

---

## Key Features

### Incremental Models
Large tables use incremental materialization for efficiency:
- Only process new data based on `pub_date` or `snapshot_date`
- Incremental runs are append-only: each run only processes rows
  with a date greater than the current max date already in the model
- Use `--full-refresh` to rebuild from scratch

### Custom Macros
- `get_incremental_filter()` - Reusable incremental logic
- `generate_schema_name()` - Auto dev/prod dataset separation

### Data Quality Tests
- Source freshness monitoring
- Unique/not_null constraints on primary keys
- Custom tests for row count validation
- Referential integrity checks

---

## Troubleshooting

### Permission Errors
- Verify service account has `bigquery.jobUser` (project-level)
- Verify service account has `bigquery.dataEditor` on all datasets

### Dataset Not Found
- Run `./setup_gcp_service_account.sh` to create datasets
- Or manually create: `bq mk --dataset --location=US times-api-ingest:<dataset_name>`

### Connection Issues
- Run `dbt debug` to diagnose
- Check `~/.dbt/profiles.yml` exists and has correct key path
- Verify key file exists: `ls -la ~/.dbt/dbt-runner-key.json`

See [`docs/service_account_setup.md`](docs/service_account_setup.md) for more details.

