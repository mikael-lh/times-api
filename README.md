# NYT Archive API – Project Summary

Context for agents: high-level goal, architecture, and decisions made so far.

---

## Goal

- Ingest **last 100 years** of NYT article metadata via the **NYT Archive API**.
- Store data so it can be loaded into **Google Cloud Storage (GCS)**, then **BigQuery**, then modeled with **dbt** for analytics.

---

## API

- **Archive API**: `GET https://api.nytimes.com/svc/archive/v1/{year}/{month}.json?api-key=...`
- One request per month; year range per spec: 1851–2019.
- Responses can be large (~20MB) and are rate-limited (per minute / per day).
- API key (and optional secret) live in **`.env`**; never committed (`.env` is in `.gitignore`).

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

| Script | Role | Input | Output |
|--------|------|--------|--------|
| **`ingest_archive.py`** | Fetch from API, save raw | API | `archive_raw/YYYY/MM.json` |
| **`transform_archive.py`** | Extract slim fields from raw | `archive_raw/` | `archive_slim/YYYY/MM.ndjson` |

- **`request.py`** – Early one-off script to explore the API and inspect article structure; not part of the main pipeline.
- **`fetch_archive_slim.py`** – Superseded by ingest + transform; can be removed.

**Run order:**  
1. `python ingest_archive.py`  
2. `python transform_archive.py`

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

## Models (`article_models.py`)

- **Pydantic** models define the slim schema and nested structures: **`SlimArticle`**, **`Keyword`**, **`BylinePerson`**.
- Used for validation when transforming (each slim dict is validated before writing) and for parsing NDJSON (e.g. `SlimArticle.model_validate_json(line)`).
- `_id` is exposed as `article_id` in Python (alias `"_id"` in JSON) to avoid Pydantic treating it as a private field.

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
├── .env                    # API key (not committed)
├── .gitignore
├── requirements.txt
├── article_models.py       # Pydantic models: SlimArticle, Keyword, BylinePerson
├── request.py              # Exploratory script
├── ingest_archive.py       # Pipeline: fetch → raw
├── transform_archive.py    # Pipeline: raw → slim (validates with SlimArticle)
├── fetch_archive_slim.py   # Legacy combined script
├── archive_raw/            # Raw API responses (YYYY/MM.json)
└── archive_slim/            # Slim NDJSON (YYYY/MM.ndjson)
```
