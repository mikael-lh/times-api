# nyt_analytics – dbt project

Transforms raw NYT data in BigQuery (`prod.*`, loaded by the Cloud
Function) into analytics-ready models.

## Layers

| Layer | Materialization | Schema (prod / ci / dev) | What it does |
|---|---|---|---|
| `staging/` | incremental view (truncate + append on `pub_date` / `snapshot_date`) | `dbt_staging` / `ci_dbt_staging` / `dev_dbt_staging` | Clean, standardize, cast types from `prod.*` source tables |
| `intermediate/` | view | `dbt_intermediate` / `ci_dbt_intermediate` / `dev_dbt_intermediate` | Flatten nested arrays (keywords, byline_person, best-seller authors) and build book spine |
| `snapshots/` | snapshot (SCD Type 2) | `dbt_snapshots` / `ci_dbt_snapshots` / `dev_dbt_snapshots` | Slowly changing history for book metadata (`strategy='check'`) |
| `marts/core/` | table | `dbt_core` / `ci_dbt_core` / `dev_dbt_core` | Facts, dimensions, bridges |
| `marts/analytics/` | table | `dbt_analytics` / `ci_dbt_analytics` / `dev_dbt_analytics` | Pre-aggregations for dashboard performance |

Schema separation is handled by `macros/generate_schema_name.sql`:
`prod` uses bare schema names, `ci` prefixes with `ci_`, anything else
(typically `dev`) prefixes with `dev_`. Models use `+schema` in
`dbt_project.yml`; snapshots use `+target_schema` (same macro, different
config key).

## Models

**Staging** (views; archive/popular also incremental where configured):
- `stg_archive_articles` – cleaned archive articles
- `stg_most_popular_articles` – cleaned daily snapshots, with `published_at` parsed to TIMESTAMP
- `stg_best_sellers` – cleaned weekly Best Sellers entries with age range parsing (PK: `published_date`, `list_name_encoded`, `rank`, `list_updated`)

**Intermediate** (views):
- `int_keywords_flattened` – one row per (article, keyword)
- `int_authors_flattened` – one row per (article, author)
- `int_best_sellers_authors_parsed` – list entries with parsed `authors` array
- `int_best_sellers_authors_flattened` – one row per (list entry, author)
- `int_best_sellers_books` – one row per `primary_isbn13` (latest list metadata)

**Core marts** (tables):
- `fct_articles` – article facts (one row per article)
- `fct_article_popularity` – one row per (snapshot_date, article)
- `fct_best_sellers` – Best Sellers list entry facts (incremental); carries `book_key` (current metadata) and `book_scd_key` (point-in-time snapshot version)
- `bridge_article_keywords` – many-to-many resolver between articles and keywords (one row per pair)
- `bridge_best_seller_authors` – many-to-many resolver between list entries and authors
- `dim_authors`, `dim_keywords`, `dim_sections`, `dim_books`, `dim_books_history` – surrogate-keyed dimensions (`dim_books` = current rows from `books_snapshot`; `dim_books_history` = all SCD versions, keyed by `book_scd_key` = `dbt_scd_id`)

**Snapshots** (`snapshots/`; schema via `+target_schema: dbt_snapshots` in `dbt_project.yml`):
- `books_snapshot` – SCD Type 2 history of book metadata and `top_rank` (best rank across all lists). Built from `int_best_sellers_books` with `top_rank` computed inline from `stg_best_sellers`.
**Analytics marts** (tables):
- `agg_articles_by_month` – monthly volume + richness
- `agg_author_performance` – author productivity
- `agg_section_trends` – section evolution by year
- `agg_keyword_trends` – keyword YoY change

## Quickstart

```bash
# From the project root
uv sync --group dbt
cd dbt_nyt_analytics

# One-time: copy/edit profiles.yml to point at your project + auth method
$EDITOR profiles.yml                  # template lives here, NOT in ~/.dbt
cp profiles.yml ~/.dbt/profiles.yml   # or symlink

uv run dbt deps                       # install packages from packages.yml
uv run dbt debug                      # test connection (default target: dev, oauth)
uv run dbt build                      # build + test everything (dev)
uv run dbt build --target prod        # production run
```

### Targets

| Target | Auth | Default dataset |
|---|---|---|
| `dev` | OAuth (`gcloud auth application-default login`) | `dev_dbt` |
| `ci` | OAuth (PR workflow overrides to `service-account-json`) | `ci_dbt` |
| `prod` | OAuth locally; CI overrides to `service-account-json` via `GCP_SA_KEY` | `dbt` |

The committed `profiles.yml` uses OAuth so it's safe to read; both CI
workflows overwrite `~/.dbt/profiles.yml` with a service-account variant
at runtime.

## Common commands

```bash
uv run dbt build                       # everything (default: dev)
uv run dbt build --select +fct_articles   # model + ancestors
uv run dbt build --select state:modified+ --defer --favor-state \
    --state ../main-branch/dbt_nyt_analytics/target/   # PR-style run
uv run dbt run --full-refresh          # rebuild incremental tables
uv run dbt docs generate && uv run dbt docs serve
```

## Custom macros

| Macro | Purpose |
|---|---|
| `generate_schema_name` | Adds `dev_` / `ci_` prefix when `target.name` is not `prod`. |
| `get_incremental_filter(date_column)` | Append-only filter: `{{ date_column }} > (select max from {{ this }})`. First run loads all history. |

## Column documentation

All column descriptions live in `docs/column_descriptions.md` as dbt
`doc()` blocks. Model, source, and snapshot `.yml` files reference them via
`{{ doc('column_name') }}`. With `+persist_docs: { relation: true,
columns: true }` set in `dbt_project.yml` for models and snapshots, those
descriptions show up directly in the BigQuery console.

## How to add a new model

1. Drop the SQL in the right layer folder (`staging/`, `intermediate/`,
   `marts/core/`, `marts/analytics/`, or `snapshots/`). Materialization
   and schema are inherited from `dbt_project.yml`. Put snapshot strategy
   config (`unique_key`, `strategy`, `check_cols`) in `_snapshots.yml`, not
   inline in the SQL file.
2. Add the model entry in the sibling `_*.yml`
   (`_staging.yml` / `_intermediate.yml` / `_core.yml` / `_analytics.yml`
   / `_snapshots.yml`) with a description and at least `unique` + `not_null`
   tests on the primary key.
3. For each new column, add a `{% docs column_name %}` block in
   `docs/column_descriptions.md` and reference it with
   `description: "{{ doc('column_name') }}"`. Reuse existing blocks
   where possible.
4. Run `uv run dbt build --select <new_model>` locally to verify schema
   + tests pass before opening a PR.

The PR workflow ([`dbt-pr.yml`](../.github/workflows/dbt-pr.yml)) will
then build only what you changed (`state:modified+`), deferred against
the latest prod manifest.

## CI/CD

| Workflow | When | What |
|---|---|---|
| [`dbt-run.yml`](../.github/workflows/dbt-run.yml) | Daily 08:00 UTC + manual | `dbt build` against prod; publishes `dbt docs generate` output to the `gh-pages` branch (GitHub Pages). |
| [`dbt-pr.yml`](../.github/workflows/dbt-pr.yml) | PR touching `dbt_nyt_analytics/**` | Builds the prod manifest from `main`, then `dbt build --select state:modified+ --defer --favor-state` on the PR branch (only what changed runs in BigQuery). |

To enable Pages-hosted docs, add `GCP_SA_KEY` (full service-account JSON
with `bigquery.jobUser` + `bigquery.dataEditor`) as a repo secret.

## Troubleshooting

- **`Permission denied`** → service account needs `bigquery.jobUser`
  (project) and `bigquery.dataEditor` on every dbt-managed dataset
  (`dbt_*`, `ci_dbt_*`, `dev_dbt_*`).
- **`Dataset not found`** → datasets are auto-created by dbt when a
  model first writes to them, but only if the SA has dataset-create
  permission. Otherwise: `bq mk --dataset --location=US <project>:<dataset>`.
- **`profiles.yml not found`** → put one at `~/.dbt/profiles.yml` (or
  set `DBT_PROFILES_DIR`). The committed `profiles.yml` here is a
  template; CI generates its own from `GCP_SA_KEY`.
- **Connection fails on first run** → `uv run dbt debug` will print
  exactly which step is broken (project, dataset, auth, network).
