# Fusion migration — changes summary

Migration completed successfully: `dbtf parse` and `dbtf compile` both finish with **0 errors** (106 resources compiled).

## Pre-migration checks

| Step | Result |
|------|--------|
| `dbtf debug` | All checks passed (BigQuery OAuth, `times-api-ingest` / `dev_dbt`) |
| `dbt-autofix` (`uvx dbt-autofix deprecations`) | **Not run** — tool crashed on Python 3.14 (`mashumaro.exceptions.UnserializableField`). Fixes applied manually per `manual_fixes/` and AGENTS.md. |

## Initial parse errors (7)

Grouped by type:

### 1. Unused config keys on source tables (`dbt1060`) — 5 errors

**Files:** `models/sources.yml`

| Location | Keys | Issue |
|----------|------|--------|
| `archive_articles`, `most_popular_articles`, `best_sellers` | `meta` at table level | Fusion only allows `config`, `columns`, `description`, etc. on source **tables** — not top-level `meta`. |
| `best_sellers` | `loaded_at_field`, `freshness` at table level | Same: must live under `config:`. |

**Fix:** Move source table settings under `config:` per Fusion YAML schema (`Tables` → `config` → `SourceConfig`).

- `loaded_at_field` and `freshness` → `config.loaded_at_field`, `config.freshness` (supported source freshness; behavior preserved).
- `partition_by` (documentation only on raw sources) → `config.meta.partition_by` because `partition_by` is not accepted on source config in this project’s Fusion validation (see `custom_configuration.md`).

### 2. Deprecated generic test arguments (`dbt1159`) — 2 errors

**File:** `models/marts/core/_core.yml` (`bridge_article_keywords`)

**Issue:** `relationships` tests used legacy top-level `to` / `field` instead of nested `arguments`.

**Fix:** Align with other tests in the same file:

```yaml
- relationships:
    arguments:
      to: ref('fct_articles')
      field: article_id
```

## Files changed

1. `models/sources.yml` — source table config structure
2. `models/marts/core/_core.yml` — two `relationships` tests on `bridge_article_keywords`

## Unsupported / deferred features

None required disabling models (no Python models, materialized views, or dynamic tables in this project).

**Note for you:** Source `partition_by` values are now **metadata only** (`config.meta.partition_by`). They were not driving dbt builds before; staging models still set real `partition_by` in model `config()` blocks.

**Freshness** on `nyt_raw.best_sellers` remains configured under `config.freshness` and should still run when you execute source freshness checks in Fusion/Core.

## Verification

```bash
dbtf parse --show-all-deprecations   # 0 errors
dbtf compile                           # 106 success
```

---

# Semantic Layer migration — changes summary

Migration of the `fct_articles` semantic model from the legacy standalone YAML spec to the new Fusion inline spec, and addition of new semantic layer features.

## Warning resolved

| Warning | Description | Fix |
|---------|-------------|-----|
| `SemanticModelDeprecated (dbt1157)` | Standalone `semantic_models:` YAML is deprecated in Fusion | Migrated to inline spec embedded in `models/marts/core/_core.yml` |

## What changed

### 1. Migrated semantic model to inline spec

**Files:** `models/semantic_models.yml` (cleared), `models/marts/core/_core.yml` (updated)

**Issue:** The legacy spec defined semantic models as a standalone top-level resource in `semantic_models.yml`. Fusion requires the new inline spec where the semantic model is embedded directly within the model's YAML entry.

**Fix:** Added `semantic_model: { enabled: true }` to the `fct_articles` entry in `_core.yml`. Moved `agg_time_dimension` and `metrics` to model-level keys (per Fusion JSON schema — they are `ModelProperties` keys, not nested inside `semantic_model`). Added column-level `entity`, `dimension`, and `granularity` annotations.

**Key schema notes (Fusion v2.0.0-preview.200):**
- `semantic_model:` only accepts `enabled`, `name`, `group`, `config` — `agg_time_dimension` is not nested here
- `metrics:` and `agg_time_dimension:` are top-level `ModelProperties` keys
- `entity:`, `dimension:`, `granularity:` are valid `ColumnProperties` keys
- `metrics:` inside column definitions is **not** supported — metrics go at the model level with an `expr:` referencing the column

### 2. Added boolean categorical dimensions

Three boolean columns added as categorical dimensions so they are available for slicing/filtering in semantic queries:
- `has_keywords`, `has_authors`, `has_multimedia` → `dimension: { type: categorical }`

### 3. Added `lengthy_articles` filtered metric

```yaml
- name: lengthy_articles
  type: simple
  agg: count
  expr: article_id
  filter: "word_count > 2000"
```

### 4. Added `metricflow_time_spine` model

**File:** `models/marts/core/metricflow_time_spine.sql`

MetricFlow requires a time spine (one row per calendar day) to power time-series aggregations and fill gaps in sparse data. Created using `dbt_utils.date_spine` covering 1851-01-01 to 2030-01-01 (matching the NYT archive date range). Registered in `_core.yml` with `time_spine: { standard_granularity_column: date_day }` and `granularity: day` on the `date_day` column.

**Note:** `dbt_utils.date_spine` must be invoked at the top level of the model file (not inside a `SELECT ... FROM`), as it expands to a full CTE-based SQL statement.

## Files changed

1. `models/semantic_models.yml` — cleared (contents moved inline)
2. `models/marts/core/_core.yml` — inline semantic model, boolean dimensions, `metricflow_time_spine` registration
3. `models/marts/core/metricflow_time_spine.sql` — new time spine model

## Unsupported features encountered

| Feature | Status |
|---------|--------|
| `expr:` inside `dimension:` config | ❌ Not supported in Fusion v2.0.0-preview.200 — derived dimensions via CASE expressions must be materialised as physical columns in the model SQL |

## Verification

```bash
dbtf parse --show-all-deprecations   # 0 errors, no dbt1157
dbt sl query --metrics article_count --group-by metric_time__month
```
