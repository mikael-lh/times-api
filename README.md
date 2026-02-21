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
| `GCP_SA_KEY` | **Full JSON** of a GCP service account key that can write to your bucket. Create a key for a service account with **Storage Object Creator** (or **Storage Admin**) on the target bucket, then paste the entire JSON as the secret value. |
| `GCS_BUCKET` | Name of the GCS bucket (e.g. `my-nyt-data`). No `gs://` prefix. |

### One-time GCP setup

1. Create a GCS bucket (e.g. `gsutil mb gs://my-nyt-data`).
2. Create a service account (or use an existing one) with permission to create/overwrite objects in that bucket (e.g. role **Storage Object Admin** or **Storage Object Creator** on the bucket).
3. Create a JSON key for that service account: **IAM & Admin → Service accounts → Keys → Add key → JSON**. Copy the entire JSON.
4. In GitHub: **Settings → Secrets and variables → Actions** → **New repository secret** for `GCP_SA_KEY` (paste the JSON) and `GCS_BUCKET` (bucket name). Add `NYTIMES_API_KEY` as above.

After that, daily runs will ingest most popular data and upload to GCS; use **Actions → Archive ingest** when you want to run (or resume) the archive pipeline.
