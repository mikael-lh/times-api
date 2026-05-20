# Testing & data quality

Four layers of validation guard the pipeline. Each layer runs at a
different point and catches a different class of bug.

| Layer | When | Tooling | Catches |
|---|---|---|---|
| 1. Unit tests | Every PR + push | `pytest` (`tests/`) | Transform logic, slim-schema parsing, GE rule wiring |
| 2. Record-level validation | During each transform run | `pydantic` (`*/models.py`) | Per-record type errors, missing required fields |
| 3. Dataset-level validation | After transform, before GCS upload | `great_expectations` (`*/validate_ge.py`) | Row counts, completeness, business rules, uniqueness |
| 4. Warehouse tests | After every `dbt build` | `dbt test` (yml + custom SQL) | Primary keys, referential integrity, custom invariants |

## 1. Unit tests (`tests/`)

Run by [`quality.yml`](../.github/workflows/quality.yml) and locally via
`uv run pytest tests/ -v`.

| File | What it covers |
|---|---|
| `test_archive_transform.py` | `archive.transform.extract_slim_article` and multimedia counting |
| `test_most_popular_transform.py` | `most_popular.transform` slim extraction |
| `test_books_transform.py` | `books.transform.flatten_overview` + `SlimBestSeller` (`Literal` enum, composite key) |
| `test_ge_validation.py` | GE suite for Archive + Most Popular: positive case and selected failures |
| `test_ge_validation_books.py` | GE suite for Best Sellers: row counts, ISBN regex, list_updated whitelist, composite uniqueness |

## 2. Record-level validation (Pydantic)

Each transform calls `SlimXxx.model_validate(rec)` for every record and
**skips invalid rows with a log message** rather than failing the entire
batch. This means a single malformed article never blocks a 100-year
archive run, but every skip is visible in the workflow logs.

Schemas live next to their transforms:

- `archive/models.py` – `SlimArticle`, `Keyword`, `BylinePerson`
- `most_popular/models.py` – `SlimMostPopularArticle`
- `books/models.py` – `SlimBestSeller`

`SlimBestSeller.list_updated` uses `Literal["WEEKLY", "MONTHLY"]` so the
API's allowed values are enforced at parse time. All slim schemas use
`extra="ignore"` so upstream additions to the API don't break the
pipeline.

## 3. Dataset-level validation (Great Expectations)

`most_popular/validate_ge.py` and `books/validate_ge.py` run as a CI
gate **between transform and GCS upload**:

```yaml
- name: Validate with Great Expectations
  run: uv run python -m most_popular.validate_ge
```

A failure exits non-zero and stops the workflow before any data reaches
GCS, so bad data never makes it into BigQuery.

| Source | Key expectations |
|---|---|
| Most Popular | 15–30 rows, `source = "New York Times"`, no future `published_date`, `id` unique |
| Best Sellers | 100–400 rows, `list_updated ∈ {WEEKLY, MONTHLY}`, ISBN-13 regex on ≥95%, `(published_date, list_name_encoded, rank)` unique |

The Archive pipeline does not currently run GE (the volume of historical
data makes per-month thresholds less meaningful), but the same pattern
could be added.

## 4. Warehouse tests (dbt)

Run as part of `uv run dbt build` (which is `dbt run` + `dbt test` for
each model). Tests are declared in each `_*.yml`:

- **`unique` + `not_null`** on every primary key (`article_id`,
  `(snapshot_date, article_id)`, `keyword_key`, …).
- **`relationships`** on every foreign key (`bridge_article_keywords`
  references `fct_articles.article_id` and `dim_keywords.keyword_key`).
- **Source freshness** monitoring via dbt sources where applicable.

[`dbt-pr.yml`](../.github/workflows/dbt-pr.yml) runs only the
state-modified slice on PRs, deferred against the prod manifest:

```bash
dbt build --select state:modified+ --defer --favor-state --state ../main-branch/dbt_nyt_analytics/target/
```

[`dbt-run.yml`](../.github/workflows/dbt-run.yml) runs the full
`dbt build --target prod` daily at 08:00 UTC.

## Local pre-commit

```bash
uv run pre-commit install        # one-time
uv run pre-commit run --all-files   # check everything
git commit --no-verify             # skip in emergencies
```

Configured hooks (see [`.pre-commit-config.yaml`](../.pre-commit-config.yaml)):
ruff (lint + format), shellcheck (`infra/*.sh`), mypy (`archive
most_popular books tests`), pytest.
