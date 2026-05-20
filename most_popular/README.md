# Most Popular API

Daily snapshot of the most-viewed NYT articles over a fixed window.

| | |
|---|---|
| **Endpoint** | `GET https://api.nytimes.com/svc/mostpopular/v2/viewed/{period}.json` |
| **Period** | This project uses `30` (last 30 days). API supports `1`, `7`, `30`. |
| **Volume** | ~20 articles per response |
| **Schedule** | Daily, 06:00 UTC ([`daily-ingest.yml`](../.github/workflows/daily-ingest.yml)) |

The "snapshot" semantics matter: each day we capture which articles were
most viewed *as of that day*, even if they were published years earlier
(see `days_since_published` in `fct_article_popularity`).

## Files

| File | Role | Input | Output |
|---|---|---|---|
| `ingest.py` | Fetch `viewed/30.json` | API | `most_popular_raw/YYYY-MM-DD/viewed_30.json` |
| `transform.py` | Extract + validate slim records | `most_popular_raw/` | `most_popular_slim/YYYY-MM-DD/viewed_30.ndjson` |
| `validate_ge.py` | Dataset-level checks with Great Expectations | latest slim NDJSON | exit 0 / 1 |
| `models.py` | `SlimMostPopularArticle` Pydantic schema | — | — |

## Run locally

```bash
# From the project root
uv run python -m most_popular.ingest
uv run python -m most_popular.transform
uv run python -m most_popular.validate_ge
```

Each step is idempotent: ingest skips dates whose raw file already exists;
transform skips slim files that already exist; validate is read-only.

## Slim schema

`SlimMostPopularArticle` (see `models.py`):

| Field | Type | Notes |
|---|---|---|
| `id` | int | API article ID. Composite key with `snapshot_date`. |
| `uri`, `url`, `source` | str | Identifiers + provenance |
| `asset_id` | int | NYT asset ID |
| `published_date`, `updated` | str | Stored as STRING in BQ; parsed to TIMESTAMP in staging via `published_at` |
| `section`, `subsection`, `byline`, `type`, `title`, `abstract` | str | Editorial dims + text |
| `des_facet`, `org_facet`, `per_facet`, `geo_facet` | list[str] | Topic / org / person / geo tags |
| `media_count_by_type` | dict[str,int] \| None | e.g. `{"image": 1}`; `None` (not `{}`) for BQ |
| `adx_keywords` | str | ADX keywords as a single semicolon-separated string |

`snapshot_date` is *not* in the slim NDJSON. The Cloud Function injects it
from the GCS path (`most_popular_slim/{snapshot_date}/...`) when loading
to BigQuery — see [`cloud_function/`](../cloud_function/README.md).

## Great Expectations checks

`validate_ge.py` runs the following dataset-level checks against the
latest slim NDJSON before upload to GCS:

- Row count between **15 and 30** (API normally returns ~20)
- `id`, `url`, `published_date`, `title` are not null
- `source` is exactly `"New York Times"`
- `published_date` matches `^\d{4}-\d{2}-\d{2}$` and is not in the future
- `id` is unique within the file

These are dataset-level invariants; record-level type checks happen in
Pydantic during transform.

## Pipeline position

```
ingest    →  most_popular_raw/YYYY-MM-DD/viewed_30.json
transform →  most_popular_slim/YYYY-MM-DD/viewed_30.ndjson
validate  →  pass / fail (CI gate before GCS upload)
GitHub Action uploads slim NDJSON to GCS
Cloud Function (cloud_function/load_most_popular.py) injects snapshot_date
  and MERGEs into prod.most_popular_articles
dbt staging → stg_most_popular_articles → fct_article_popularity
```
