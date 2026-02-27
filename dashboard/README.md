## NYT Archive Overview Dashboard

A Streamlit dashboard for comprehensive analysis of NYT archive data with interactive filtering.

### Features

- **Time Series**: Articles published and average word count by month
- **Breakdowns**: By section, news desk, and type of material
- **Top Lists**: Top 10 keywords and authors by article count
- **Comprehensive Filtering**: Date range, sections, news desks, material types, authors, keywords
- All filters are interconnected and apply to all visualizations

### Quick Start

1. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

2. Configure credentials:
   ```bash
   cp .env.example .env
   # Edit .env with your GCP project ID and credentials path
   ```

3. Run the dashboard:
   ```bash
   streamlit run pages/1_📰_Archive_Overview.py
   ```

### Configuration

Edit `.env` file:
- `GCP_PROJECT_ID`: Your GCP project ID
- `GCP_CREDENTIALS_PATH`: Path to service account JSON key
- `DBT_CORE_DATASET`: Core dataset name (default: dbt_core)
- `DBT_ANALYTICS_DATASET`: Analytics dataset name (default: dbt_analytics)
- `DBT_STAGING_DATASET`: Staging dataset name (default: dbt_staging)

### Data Sources

The dashboard queries dbt models in BigQuery:
- `dbt_core.fct_articles` - Main article fact table
- `dbt_analytics.agg_author_performance` - Author metrics
- `dbt_analytics.agg_keyword_trends` - Keyword trends
- `dbt_staging.stg_archive_articles` - Staging table for filtering
