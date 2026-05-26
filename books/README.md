# Books API (Best Sellers)

Weekly snapshot of every NYT Best Sellers list and its books.

| | |
|---|---|
| **Endpoint** | `GET https://api.nytimes.com/svc/books/v3/lists/overview.json` |
| **Volume** | One request returns all ~20 lists and ~250 books for a print week |
| **Coverage** | 2017–present |
| **Publish cadence** | Lists publish Wed ~7 pm ET; appear in print 11 days later |
| **Schedule** | Thursday 08:00 UTC ([`books-ingest.yml`](../.github/workflows/books-ingest.yml)) |
| **Rate limit** | NYT free tier: 500 req/day, ~5 req/min |

Optional query param: `published_date=YYYY-MM-DD` (the print Sunday). Omit
for the latest list.

## Files

| File | Role | Input | Output |
|---|---|---|---|
| `ingest.py` | Fetch overview, key output by response's `published_date` | API | `books_raw/YYYY-MM-DD/overview.json` |
| `transform.py` | Flatten lists → books, validate with Pydantic | `books_raw/` | `books_slim/YYYY-MM-DD/overview.ndjson` |
| `validate_ge.py` | Dataset-level GE checks | latest slim NDJSON | exit 0 / 1 |
| `models.py` | `SlimBestSeller` Pydantic schema | — | — |
| `backfill.py` | Historical backfill from 2008-06-15 to today (currently untracked) | API | `books_raw/...` |

## Run locally

```bash
# From the project root
uv run python -m books.ingest                          # latest print week
uv run python -m books.ingest --published-date 2025-05-04
uv run python -m books.ingest --overwrite              # re-fetch even if file exists

uv run python -m books.transform
uv run python -m books.validate_ge
```

## Slim schema

`SlimBestSeller` (see `models.py`) – one row per `(published_date,
list_name_encoded, rank, list_updated)`:

| Field | Type | Notes |
|---|---|---|
| `published_date` | str | Print publication date (Sunday) — required, part of composite key |
| `list_name_encoded` | str | e.g. `hardcover-fiction` — required, part of composite key |
| `list_display_name` | str | Human-readable list name |
| `list_updated` | `Literal["WEEKLY","MONTHLY"]` | Enforced via Pydantic at parse time — part of composite key |
| `rank` | int | 1-based — required, part of composite key |
| `rank_last_week`, `weeks_on_list`, `asterisk`, `dagger` | int | Movement and footnote markers |
| `primary_isbn13`, `title`, `author`, `contributor`, `contributor_note`, `publisher`, `description` | str | Book metadata |
| `book_image`, `amazon_product_url`, `age_group`, `book_review_link`, `sunday_review_link` | str | Links |

`SlimBestSeller` uses `extra="ignore"`, so upstream additions to the API
response are silently dropped rather than failing validation.

## Great Expectations checks

`validate_ge.py` runs before GCS upload:

- Row count between **100 and 400** (~250 typical)
- `published_date`, `list_name_encoded`, `rank`, `title` not null
- `list_updated` in `{WEEKLY, MONTHLY}`
- `published_date` matches `^\d{4}-\d{2}-\d{2}$`
- `primary_isbn13` matches `^\d{13}$` (≥95% of rows)
- `(published_date, list_name_encoded, rank, list_updated)` is unique

## Pipeline position

```
ingest    →  books_raw/YYYY-MM-DD/overview.json
transform →  books_slim/YYYY-MM-DD/overview.ndjson  (~250 rows, one per book per list)
validate  →  pass / fail (CI gate before GCS upload)
GitHub Action uploads slim NDJSON to GCS
Cloud Function (cloud_function/load_best_sellers.py) parses published_date
  to DATE and MERGEs into prod.best_sellers (dedup by (published_date,
  list_name_encoded, rank, list_updated))
```

Note: `prod.best_sellers` is **not yet modelled in dbt**. It currently
sits as a raw source table available for ad hoc queries.
