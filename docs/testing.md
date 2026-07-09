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
| Best Sellers | 100–400 rows, `list_updated ∈ {WEEKLY, MONTHLY}`, ISBN-13 regex on ≥95%, `(published_date, list_name_encoded, rank, list_updated)` unique |

The Archive pipeline does not currently run GE (the volume of historical
data makes per-month thresholds less meaningful), but the same pattern
could be added.

## 4. Warehouse tests (dbt)

CI and local runs use **dbt Fusion** (`dbt==2.0.0rc194` via uv). From the
repo root, run `uv sync --group dbt` before `uv run dbt build`.

Run as part of `uv run dbt build` (which is `dbt run` + `dbt test` for
each model). Tests are declared in each `_*.yml`:

- **`unique` + `not_null`** on every primary key (`article_id`,
  `(snapshot_date, article_id)`, `keyword_key`, …).
- **`relationships`** on every foreign key (`bridge_article_keywords`
  references `fct_articles.article_id` and `dim_keywords.keyword_key`).
- **Source freshness** on `nyt_raw.most_popular_articles` (daily snapshot;
  warn 1d / error 2d) and `nyt_raw.best_sellers` (weekly list; warn 5d /
  error 8d). `archive_articles` is static and not checked. Freshness uses
  `timestamp(...)` on DATE columns because Fusion requires a timestamp
  `loaded_at_field`.

[`dbt-pr.yml`](../.github/workflows/dbt-pr.yml) runs only the
state-modified slice on PRs, deferred against the prod manifest:

```bash
dbt build --select state:modified+ --defer --favor-state --state ../main-branch/dbt_nyt_analytics/target/
```

[`dbt-run.yml`](../.github/workflows/dbt-run.yml) runs
`dbt source freshness` then a selective prod build daily at 10:00 UTC
(four hours after Most Popular ingest at 06:00 UTC; two hours after Books
ingest on Thursdays at 08:00 UTC). When artifacts from the latest
prior successful daily run are available, it builds only `state:modified+`
(code changes since last run) and `source_status:fresher+` (sources with
new data plus downstream models); otherwise it falls back to a full build.
Manual runs can still override with the `select` workflow input.

[`dbt-deploy.yml`](../.github/workflows/dbt-deploy.yml) runs on push to
`main` when `dbt_nyt_analytics/**` changes: compile a prod manifest from
pre-push `main`, then `dbt build --target prod --select state:modified+
--defer --favor-state` (full prod build when no prior state exists). This
is the post-merge CD step after [`dbt-pr.yml`](../.github/workflows/dbt-pr.yml)
validates the same slice in `ci_dbt_<PR number>`.

## Local pre-commit

```bash
uv run pre-commit install        # one-time
uv run pre-commit run --all-files   # check everything
git commit --no-verify             # skip in emergencies
```

**What runs via `uv run`:** project tools you invoke yourself (`dbt`,
`pytest`, `mypy`, `pre-commit`) and the local `dbt-parse-manifest` hook
(`uv run dbt deps` / `uv run dbt parse`). **What does not:** hooks from
external pre-commit repos (ruff, shellcheck, dbt-checkpoint) — pre-commit
installs those in their own cached environments; dbt-checkpoint only reads
`target/manifest.json` and does not shell out to dbt.

Configured hooks (see [`.pre-commit-config.yaml`](../.pre-commit-config.yaml)):
ruff (lint + format), shellcheck (`infra/*.sh`), mypy (`archive
most_popular books tests`), pytest, and **dbt-checkpoint** on
`dbt_nyt_analytics/models/` (properties file and model `description` in
`_*.yml`). When dbt files change, a local hook runs
`dbt parse` first to refresh `target/manifest.json`.

The same dbt-checkpoint hooks run in CI via
[`dbt-pr.yml`](../.github/workflows/dbt-pr.yml) (`pre-commit run …
--all-files`) after `dbt parse`, so PRs cannot merge undocumented models
even if `--no-verify` was used locally.

### SQL style (SQLFluff)

[SQLFluff](https://docs.sqlfluff.com/) enforces BigQuery SQL layout on
`dbt_nyt_analytics/models/` (lint + auto-fix). Config: [`.sqlfluff`](../.sqlfluff);
Jinja stubs in [`dbt_nyt_analytics/sqlfluff_macros/`](../dbt_nyt_analytics/sqlfluff_macros/)
allow linting without a warehouse connection. Snapshots are excluded (see
[`.sqlfluffignore`](../.sqlfluffignore)).

```bash
uv run sqlfluff fix dbt_nyt_analytics/models
uv run sqlfluff lint dbt_nyt_analytics/models
```

CI runs `sqlfluff fix --check` then `sqlfluff lint` in `dbt-pr.yml`.
