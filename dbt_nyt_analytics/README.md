# NYT Analytics dbt Project

This dbt project transforms raw NYT article data from BigQuery into analytics-ready models.

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

## Setup

### Prerequisites
- Python 3.11+
- dbt-bigquery installed (`pip install dbt-bigquery`)
- GCP service account with BigQuery access

### Local Development

1. Copy the profile template:
   ```bash
   cp profiles.yml.example ~/.dbt/profiles.yml
   ```

2. Update `~/.dbt/profiles.yml` with your credentials

3. Test the connection:
   ```bash
   dbt debug
   ```

4. Install packages:
   ```bash
   dbt deps
   ```

5. Run models:
   ```bash
   dbt run
   ```

6. Run tests:
   ```bash
   dbt test
   ```

## Running Models

```bash
# Run all models
dbt run

# Run specific model and its dependencies
dbt run --select +fct_articles

# Full refresh (rebuild incremental tables)
dbt run --full-refresh

# Run tests
dbt test

# Generate docs
dbt docs generate
dbt docs serve
```

## Datasets Created

| Dataset | Description |
|---------|-------------|
| `dbt_staging` | Staging layer views |
| `dbt_core` | Fact and dimension tables |
| `dbt_analytics` | Aggregated analytics tables |

## CI/CD

The project runs automatically via GitHub Actions:
- **Schedule**: Daily at 8:00 UTC (after ingestion completes at 6:00 UTC)
- **Manual**: Can be triggered with optional `--full-refresh` and `--select` flags

See `.github/workflows/dbt-run.yml` for details.
