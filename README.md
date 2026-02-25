# NYT Article Ingestion – Project Summary

Context for agents: high-level goal, architecture, and decisions made so far.

---

## Goal

- Ingest **last 100 years** of NYT article metadata via the **NYT Archive API**.
- Ingest **most popular articles** (most viewed, last 30 days) via the **NYT Most Popular API** with daily automation.
- Store data so it can be loaded into **Google Cloud Storage (GCS)**, then **BigQuery**, then modeled with **dbt** for analytics.

---

## APIs

### Archive API
- **Endpoint**: `GET https://api.nytimes.com/svc/archive/v1/{year}/{month}.json?api-key=...`
- One request per month; year range per spec: 1851–2019.
- Responses can be large (~20MB) and are rate-limited (per minute / per day).

### Most Popular API
- **Endpoint**: `GET https://api.nytimes.com/svc/mostpopular/v2/viewed/{period}.json?api-key=...`
- Period options: 1, 7, or 30 (days)
- Returns top 20 most viewed articles for the specified period
- Designed for daily ingestion to track trending content

**Common**: API key lives in **`.env`**; never committed (`.env` is in `.gitignore`).

---

## Architecture: Ingestion vs Transformation

We **separate ingestion from transformation**:

1. **Ingestion** – Call API, save **raw** response JSON. No shaping.
2. **Transformation** – Read raw, extract a slim set of fields, write **slim** output.

Reasons:
- Avoid re-fetching when extraction logic or schema changes (rate limits, 12s between calls).
- Raw data is the source of truth; transformation can be re-run or moved (e.g. into dbt) later.
- Easier to debug (raw vs transformed) and test (transform with mock raw).

---

## Scripts and Data Flow

### Archive API (Historical Data)

| Script | Role | Input | Output |
|--------|------|--------|--------|
| **`archive/ingest.py`** | Fetch from API, save raw | API | `archive_raw/YYYY/MM.json` |
| **`archive/transform.py`** | Extract slim fields from raw | `archive_raw/` | `archive_slim/YYYY/MM.ndjson` |

- **`request.py`** – Early one-off script to explore the API and inspect article structure; not part of the main pipeline.
- **`fetch_archive_slim.py`** – Superseded by ingest + transform; can be removed.

**Run order (from project root):**  
1. `python -m archive.ingest`  
2. `python -m archive.transform`

### Most Popular API (Daily Trending Data)

| Script | Role | Input | Output |
|--------|------|--------|--------|
| **`most_popular/ingest.py`** | Fetch most viewed (30 days), save raw | API | `most_popular_raw/YYYY-MM-DD/viewed_30.json` |
| **`most_popular/transform.py`** | Extract slim fields from raw | `most_popular_raw/` | `most_popular_slim/YYYY-MM-DD/viewed_30.ndjson` |
| **`most_popular/scheduler.py`** | Python-based daily scheduler | - | Runs ingestion + transform daily |
| **`run_daily_ingestion.sh`** | Shell script for cron automation | - | Runs ingestion + transform |

**Note:** `scheduler.py` and `run_daily_ingestion.sh` are optional/local automation; they are not in the repo. Use GitHub Actions (below) or run ingest/transform manually.

**Run order (manual, from project root):**  
1. `python -m most_popular.ingest`  
2. `python -m most_popular.transform`

**Automation (choose one):**
- **GitHub Actions**: Daily workflow runs at 06:00 UTC, then uploads to GCS. See [GitHub Actions (GCS)](#github-actions-gcs) below.
- **Cron**: `0 6 * * * /path/to/run_daily_ingestion.sh >> /var/log/nyt_ingestion.log 2>&1`
- **Python scheduler**: `python -m most_popular.scheduler` (runs in foreground, executes daily at 06:00)

---

## Ingestion (Archive – `archive/ingest.py`)

- **Config**: `START_YEAR`, `END_YEAR` (e.g. 1920–2020 for 100 years), `SLEEP_SECONDS` (12+ between requests).
- **Idempotent**: Skips months that already have a file in `archive_raw/` (safe to resume).
- **Error handling**: Catches HTTP errors (e.g. 4xx/5xx); prints and continues to next month instead of stopping the whole run.
- **User feedback**: Separate "Fetched" and "Ingested" messages; can distinguish fetch failure vs. success with 0 articles (empty `docs`).
- **Output**: One JSON file per month: full API response (e.g. `response.docs`, `response.meta`).

---

## Transformation (Archive – `archive/transform.py`)

- **Input**: All `archive_raw/*/*.json` (discovered via `RAW_DIR.glob("*/*.json")`), sorted.
- **Output**: One NDJSON file per month in `archive_slim/YYYY/MM.ndjson` (one JSON object per line; good for BigQuery).
- **Idempotent**: Skips months that already have a slim file unless `overwrite=True`.
- **Extraction**: Each raw article doc is reduced to a "slim" dict (see fields below).
- **Validation**: Slim dicts are validated with **Pydantic** (`SlimArticle.model_validate`); invalid records are skipped and logged instead of stopping the run.

---

## Slim Schema (Analysis-Ready Fields)

Chosen for analytics, BigQuery, and dbt:

| Field | Description |
|-------|-------------|
| `_id`, `uri` | Identifiers |
| `pub_date`, `section_name`, `news_desk`, `type_of_material`, `document_type` | Dimensions / time |
| `word_count`, `web_url` | Numeric / link |
| `headline_main`, `byline_original`, `abstract`, `snippet` | Text (one of abstract/snippet used) |
| `keywords` | List of keyword dicts (topic/subject analysis) |
| `byline_person` | Full list of person dicts (author analysis) |
| `multimedia_count_by_type` | Dict of counts by type (e.g. `{"image": 5}`) |

Defensive handling: list fields use `or []` so they're always lists (safe to iterate). Scalars can be `None` when missing.

---

## Models

### Archive Models (`archive/models.py`)

- **Pydantic** models define the slim schema and nested structures: **`SlimArticle`**, **`Keyword`**, **`BylinePerson`**.
- Used for validation when transforming (each slim dict is validated before writing) and for parsing NDJSON (e.g. `SlimArticle.model_validate_json(line)`).
- `_id` is exposed as `article_id` in Python (alias `"_id"` in JSON) to avoid Pydantic treating it as a private field.

### Most Popular Models (`most_popular/models.py`)

- **`SlimMostPopularArticle`** – analysis-ready slim schema; validated when transforming (same pattern as Archive: extract from raw dict → validate slim → write). Raw API response is read via dict access.

---

## Development setup

- Install [uv](https://docs.astral.sh/uv/) (e.g. `brew install uv`).
- From the project root, run **`uv sync`** to create a virtualenv (`.venv`) and install dependencies from `uv.lock`.
- If you don’t have Python 3.12: **`uv python install 3.12`**, then `uv sync`.
- Run scripts with **`uv run python -m archive.ingest`** (or `most_popular.ingest` / `archive.transform` / `most_popular.transform`) so they use the project environment.

### Pre-commit Hooks

Install pre-commit hooks to run quality checks before each commit:

```bash
uv run pre-commit install
```

This sets up automatic checks (ruff, mypy, shellcheck, pytest) that run on `git commit`. If any check fails, the commit is aborted so you can fix issues before they reach CI.

**Manual run:** `uv run pre-commit run --all-files`  
**Skip checks:** `git commit --no-verify` (use sparingly)

---

## Quality Checks

The repo uses automated quality checks (lint, format, type-check, test) that run on every PR and push to main.

### Python

- **Ruff** (lint + format): `uv run ruff check .` and `uv run ruff format --check .`
- **Mypy** (type checking): `uv run mypy archive most_popular tests`
- **Pytest** (tests): `uv run pytest tests/ -v`

### Shell Scripts

- **ShellCheck** (shell script linter): Checks `infra/*.sh` for syntax errors, quoting issues, and best practices
- Install locally: `brew install shellcheck` (macOS) or `apt-get install shellcheck` (Ubuntu)
- Run: `shellcheck infra/*.sh`

All checks run automatically in CI via `.github/workflows/quality.yml`.

---

## Conventions and Tech

- **Secrets**: `.env` with `NYTIMES_API_KEY` (and optional secret); loaded via `python-dotenv`.
- **Paths**: `pathlib.Path` for `archive_raw/`, `archive_slim/`.
- **Dependencies**: `requests`, `python-dotenv`, `pydantic` (see `pyproject.toml` and `uv.lock`).
- **.gitignore**: `.env`, `.venv/`, `archive_raw/`, `archive_slim/`.

---

## File Layout (Relevant)

```
.
├── .env                        # API key (not committed)
├── .gitignore
├── pyproject.toml              # Project metadata, dependencies, tool config
├── uv.lock                     # Locked dependency versions (reproducible installs)
│
├── archive/                    # Archive API (historical)
│   ├── models.py               # SlimArticle, Keyword, BylinePerson
│   ├── ingest.py               # Fetch → archive_raw/YYYY/MM.json
│   └── transform.py            # archive_raw/ → archive_slim/YYYY/MM.ndjson
├── archive_raw/                # Raw API responses (YYYY/MM.json)
├── archive_slim/               # Slim NDJSON (YYYY/MM.ndjson)
│
├── most_popular/               # Most Popular API (daily trending)
│   ├── models.py               # SlimMostPopularArticle
│   ├── ingest.py               # Fetch → most_popular_raw/YYYY-MM-DD/viewed_30.json
│   ├── transform.py            # most_popular_raw/ → most_popular_slim/
│   └── scheduler.py            # Daily scheduler (ingest + transform)
├── most_popular_raw/           # Raw API responses (YYYY-MM-DD/viewed_30.json)
└── most_popular_slim/          # Slim NDJSON (YYYY-MM-DD/viewed_30.ndjson)
```

---

## GitHub Actions (GCS)

Ingestion is automated with GitHub Actions so that **ingested files end up in GCS**. No Cloud Run or scheduler to configure; the same repo that runs locally runs in the cloud.

### Workflows

| Workflow | Trigger | Steps | GCS path |
|----------|---------|--------|----------|
| **Daily ingest** (`.github/workflows/daily-ingest.yml`) | Schedule 06:00 UTC daily + manual | Most Popular ingest → transform → upload | `gs://BUCKET/nyt-ingest/most_popular_raw/`, `.../most_popular_slim/` |
| **Archive ingest** (`.github/workflows/archive-ingest.yml`) | Manual only | Archive ingest → transform → upload | `gs://BUCKET/nyt-ingest/archive_raw/`, `.../archive_slim/` |

**Archive note:** A full 100-year archive run (12s+ per month) can approach the 6-hour job limit. Adjust `START_YEAR`/`END_YEAR` in `archive/ingest.py` to run in chunks, or trigger the workflow periodically to resume (ingest skips existing months).

### Required repository secrets

Add these in **Settings → Secrets and variables → Actions**:

| Secret | Description |
|--------|-------------|
| `NYTIMES_API_KEY` | Your NYT API key (same as in `.env` locally). |
| `GCP_SA_KEY` | **Full JSON** of the `dbt-runner` service account key for dbt transformations. This account needs `bigquery.jobUser` and `bigquery.dataEditor` roles. |
| `GCP_SA_KEY_INGEST` | **Full JSON** of a GCP service account key for data ingestion. This account needs **Storage Object Creator** (or **Storage Admin**) role on the GCS bucket. |
| `GCP_SA_KEY_DEPLOY` | **Full JSON** of a GCP service account key for deploying Cloud Functions. This account needs Cloud Functions deployment permissions. |
| `GCS_BUCKET` | Name of the GCS bucket (e.g. `my-nyt-data`). No `gs://` prefix. |

### One-time GCP setup

1. Create a GCS bucket (e.g. `gsutil mb gs://my-nyt-data`).
2. Create service accounts:
   - **For data ingestion** (`github-actions-gcs-upload`): Create a service account with **Storage Object Admin** or **Storage Object Creator** role on the bucket. Generate a JSON key and add it as `GCP_SA_KEY_INGEST` in GitHub Secrets.
   - **For dbt** (`dbt-runner`): Create a service account with `bigquery.jobUser` and `bigquery.dataEditor` roles. Generate a JSON key and add it as `GCP_SA_KEY` in GitHub Secrets.
   - **For Cloud Function deployment** (can reuse ingestion SA or create separate): Ensure it has Cloud Functions deployment permissions. Add its JSON key as `GCP_SA_KEY_DEPLOY` in GitHub Secrets.
3. In GitHub: **Settings → Secrets and variables → Actions** → **New repository secret** for each service account key and `GCS_BUCKET` (bucket name). Add `NYTIMES_API_KEY` as above.

After that, daily runs will ingest most popular data and upload to GCS; use **Actions → Archive ingest** when you want to run (or resume) the archive pipeline.

---

## BigQuery Load (Real-Time)

A **Cloud Function** automatically loads slim NDJSON files from GCS into **BigQuery** whenever they're written. This provides real-time data availability for analytics and dbt models.

### Architecture

- **Trigger**: Eventarc monitors the GCS bucket for `object.finalize` events.
- **Function**: Receives the event, filters for `archive_slim/` or `most_popular_slim/` paths, loads the file to a staging table, MERGEs into the final table (deduplicating by key), and records the load in a manifest table.
- **Three datasets** (staging, metadata, prod):
  - **staging**: `archive_articles`, `most_popular_articles` (transient; truncated after each load)
  - **metadata**: `load_manifest` (tracks loaded files for idempotency)
  - **prod**: `archive_articles` (partitioned by `pub_date`), `most_popular_articles` (partitioned by `snapshot_date`)

### Setup

**One-time BigQuery setup** (run before deploying the function):

```bash
GCP_PROJECT=your-project ./infra/create_bq_tables.sh
```

This creates three datasets (`staging`, `metadata`, `prod`) and all required tables using the schema definitions in `schema/`. Dataset names are hardcoded in the script.

**Deploy the Cloud Function**:

The function is deployed automatically via GitHub Actions when you push changes to `cloud_function/`, `infra/deploy.sh`, or `schema/`. The deployment script automatically copies schema files from `schema/` to `cloud_function/schema/` before deploying. You can also deploy manually:

```bash
GCP_PROJECT=your-project GCS_BUCKET=your-bucket GCS_PREFIX=nyt-ingest \
BQ_STAGING_DATASET=staging BQ_METADATA_DATASET=metadata BQ_PROD_DATASET=prod \
FUNCTION_NAME=nyt-bq-loader REGION=europe-west1 \
./infra/deploy.sh
```

**Required environment variables** (must be set in GitHub Actions variables and when deploying locally):
- `GCP_PROJECT`: Your GCP project ID
- `GCS_BUCKET`: GCS bucket name (e.g. `my-nyt-data`)
- `GCS_PREFIX`: Prefix for objects (e.g. `nyt-ingest`)
- `BQ_STAGING_DATASET`: Staging dataset name (e.g. `staging`)
- `BQ_METADATA_DATASET`: Metadata dataset name (e.g. `metadata`)
- `BQ_PROD_DATASET`: Production dataset name (e.g. `prod`)
- `FUNCTION_NAME`: Cloud Function name (e.g. `nyt-bq-loader`)
- `REGION`: Cloud Function region; must match the GCS bucket region for the Eventarc trigger (e.g. `europe-west1`)

All variables are required; the scripts will fail with a clear error if any are missing.

### How It Works

1. GitHub Actions workflows write slim NDJSON files to GCS (e.g. `archive_slim/2020/05.ndjson`).
2. Eventarc triggers the Cloud Function with the bucket and object name.
3. The function:
   - Checks if the path matches `archive_slim/` or `most_popular_slim/`
   - Checks the manifest to avoid re-loading (optional idempotency)
   - Loads the file to the staging dataset table using `bq load`
   - MERGEs from staging to prod (dedup by `article_id` for archive, `(snapshot_date, id)` for most popular)
   - Records the load in the metadata dataset (`load_manifest`)
   - Truncates the staging table
4. Data is immediately available in the prod dataset for querying and dbt transformations.

### File Layout (BigQuery Pipeline)

```
.
├── schema/                        # BigQuery schema definitions (JSON, single source of truth)
│   ├── archive_articles.json      # Archive table schema
│   └── most_popular_articles.json # Most Popular table schema
│
├── cloud_function/                # Cloud Function source
│   ├── schema/                    # (Auto-generated during deployment, in .gitignore)
│   ├── main.py                    # Entrypoint (receives Cloud Events)
│   ├── config.py                  # Configuration (env vars)
│   ├── load_archive.py            # Archive loader (staging → MERGE → manifest)
│   ├── load_most_popular.py       # Most Popular loader (with snapshot_date)
│   └── requirements.txt           # Function dependencies
│
├── infra/                         # Infrastructure scripts
│   ├── create_bq_tables.sh        # One-time BigQuery setup
│   └── deploy.sh                  # Deploy Cloud Function (copies schema/ → cloud_function/schema/)
│
└── .github/workflows/
    └── deploy-function.yml        # Auto-deploy function on push
```

### Permissions

The Cloud Function's service account needs:
- **BigQuery Data Editor** (or equivalent) on the three datasets (staging, metadata, prod)
- **Storage Object Viewer** on the GCS bucket

These are typically granted automatically during deployment, but verify if you encounter permission errors.
