# Archive API

Historical NYT article metadata, sourced from the
[Archive API](https://developer.nytimes.com/docs/archive-product/1/overview).

| | |
|---|---|
| **Endpoint** | `GET https://api.nytimes.com/svc/archive/v1/{year}/{month}.json` |
| **Granularity** | One request per (year, month) |
| **Range** | 1851–2019 (spec). This project defaults to 1920–2019 (100 years). |
| **Response size** | Can be ~20 MB per month |
| **Rate limit** | 12 s minimum between calls; 500 requests/day |

## Files

| File | Role | Input | Output |
|---|---|---|---|
| `ingest.py` | Fetch monthly archives | API | `archive_raw/YYYY/MM.json` |
| `transform.py` | Extract slim records, validate with Pydantic | `archive_raw/` | `archive_slim/YYYY/MM.ndjson` |
| `models.py` | `SlimArticle`, `Keyword`, `BylinePerson` Pydantic schemas | — | — |

## Run locally

```bash
# From the project root
uv run python -m archive.ingest        # months not already in GCS
uv run python -m archive.transform     # all raw files → slim NDJSON
```

`ingest.py` skips months that already exist in GCS (`gs://$GCS_BUCKET/$GCS_PREFIX/archive_raw/...`)
when `GCS_BUCKET` is set, so re-runs are safe and resumable. `transform.py`
skips months whose slim NDJSON already exists locally.

Tunable env vars / module constants in `ingest.py`:

| Setting | Default | Notes |
|---|---|---|
| `START_YEAR` / `END_YEAR` | 1920 / 2020 (exclusive) | Edit in source |
| `SLEEP_SECONDS` | 13 | One full minute → ~5 requests |
| `ARCHIVE_MAX_REQUESTS` (env) | unlimited | Cap a single run to stay under the daily quota |
| `GCS_BUCKET` / `GCS_PREFIX` (env) | unset | When set, ingest skips months already in GCS |

## Slim schema

`SlimArticle` (see `models.py`) – one row per article:

| Field | Type | Notes |
|---|---|---|
| `article_id` | str | NYT `_id`; primary key. Aliased from `_id` on parse. |
| `uri` | str | NYT URI |
| `pub_date` | str | ISO 8601; later cast to DATE in BQ |
| `section_name`, `news_desk`, `type_of_material`, `document_type` | str | Editorial dimensions |
| `word_count` | int | Defaults to 0 in staging if null |
| `web_url` | str | Public URL |
| `headline_main`, `byline_original`, `abstract`, `snippet` | str | Text |
| `keywords` | list[`Keyword`] | name, value, rank, major |
| `byline_person` | list[`BylinePerson`] | firstname, lastname, middlename, qualifier |
| `multimedia_count_by_type` | dict[str,int] \| None | e.g. `{"image": 5}`; `None` (not `{}`) for BQ compatibility |

Invalid records are skipped and logged (not raised) so a single bad doc
can't kill a month-long batch.

## Pipeline position

```
ingest.py  →  archive_raw/YYYY/MM.json
transform  →  archive_slim/YYYY/MM.ndjson
GitHub Action uploads slim NDJSON to GCS
Cloud Function (cloud_function/load_archive.py) MERGEs into prod.archive_articles
dbt staging → stg_archive_articles → fct_articles, dim_*, agg_*
```

A full 1920–2019 run at ~13 s/request approaches the 6-hour GitHub job
limit; the `archive-ingest.yml` workflow uses `ARCHIVE_MAX_REQUESTS=500` so
each run stays inside the daily NYT quota and the next run resumes from
where GCS left off.
