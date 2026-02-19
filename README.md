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
| **`ingest_archive.py`** | Fetch from API, save raw | API | `archive_raw/YYYY/MM.json` |
| **`transform_archive.py`** | Extract slim fields from raw | `archive_raw/` | `archive_slim/YYYY/MM.ndjson` |

- **`request.py`** – Early one-off script to explore the API and inspect article structure; not part of the main pipeline.
- **`fetch_archive_slim.py`** – Superseded by ingest + transform; can be removed.

**Run order:**  
1. `python ingest_archive.py`  
2. `python transform_archive.py`

### Most Popular API (Daily Trending Data)

| Script | Role | Input | Output |
|--------|------|--------|--------|
| **`ingest_most_popular.py`** | Fetch most viewed (30 days), save raw | API | `most_popular_raw/YYYY-MM-DD/viewed_30.json` |
| **`transform_most_popular.py`** | Extract slim fields from raw | `most_popular_raw/` | `most_popular_slim/YYYY-MM-DD/viewed_30.ndjson` |
| **`scheduler.py`** | Python-based daily scheduler | - | Runs ingestion + transform daily |
| **`run_daily_ingestion.sh`** | Shell script for cron automation | - | Runs ingestion + transform |

**Run order (manual):**  
1. `python ingest_most_popular.py`  
2. `python transform_most_popular.py`

**Automation (choose one):**
- **Cron**: `0 6 * * * /path/to/run_daily_ingestion.sh >> /var/log/nyt_ingestion.log 2>&1`
- **Python scheduler**: `python scheduler.py` (runs in foreground, executes daily at 06:00)

---

## Ingestion (`ingest_archive.py`)

- **Config**: `START_YEAR`, `END_YEAR` (e.g. 1920–2020 for 100 years), `SLEEP_SECONDS` (12+ between requests).
- **Idempotent**: Skips months that already have a file in `archive_raw/` (safe to resume).
- **Error handling**: Catches HTTP errors (e.g. 4xx/5xx); prints and continues to next month instead of stopping the whole run.
- **User feedback**: Separate "Fetched" and "Ingested" messages; can distinguish fetch failure vs. success with 0 articles (empty `docs`).
- **Output**: One JSON file per month: full API response (e.g. `response.docs`, `response.meta`).

---

## Transformation (`transform_archive.py`)

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

### Archive Models (`article_models.py`)

- **Pydantic** models define the slim schema and nested structures: **`SlimArticle`**, **`Keyword`**, **`BylinePerson`**.
- Used for validation when transforming (each slim dict is validated before writing) and for parsing NDJSON (e.g. `SlimArticle.model_validate_json(line)`).
- `_id` is exposed as `article_id` in Python (alias `"_id"` in JSON) to avoid Pydantic treating it as a private field.

### Most Popular Models (`most_popular_models.py`)

- **Pydantic** models for Most Popular API: **`MostPopularArticle`**, **`MostPopularResponse`**, **`Media`**, **`MediaMetadata`**.
- Validates the full API response structure including nested media objects.
- Used for both validation and transformation to slim format.

---

## Conventions and Tech

- **Secrets**: `.env` with `NYTIMES_API_KEY` (and optional secret); loaded via `python-dotenv`.
- **Paths**: `pathlib.Path` for `archive_raw/`, `archive_slim/`.
- **Dependencies**: `requests`, `python-dotenv`, `pydantic` (see `requirements.txt`).
- **.gitignore**: `.env`, `archive_raw/`, `archive_slim/`.

---

## File Layout (Relevant)

```
.
├── .env                        # API key (not committed)
├── .gitignore
├── requirements.txt
│
│   # Archive API (historical)
├── article_models.py           # Pydantic models: SlimArticle, Keyword, BylinePerson
├── ingest_archive.py           # Pipeline: fetch → raw
├── transform_archive.py        # Pipeline: raw → slim
├── archive_raw/                # Raw API responses (YYYY/MM.json)
├── archive_slim/               # Slim NDJSON (YYYY/MM.ndjson)
│
│   # Most Popular API (daily trending)
├── most_popular_models.py      # Pydantic models: MostPopularArticle, Media, etc.
├── ingest_most_popular.py      # Pipeline: fetch → raw (most viewed, 30 days)
├── transform_most_popular.py   # Pipeline: raw → slim
├── scheduler.py                # Python-based daily scheduler
├── run_daily_ingestion.sh      # Shell script for cron automation
├── most_popular_raw/           # Raw API responses (YYYY-MM-DD/viewed_30.json)
└── most_popular_slim/          # Slim NDJSON (YYYY-MM-DD/viewed_30.ndjson)
```
