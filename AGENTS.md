# AGENTS.md

Guidance for cloud agents working in this repository.

## Cursor Cloud specific instructions

### Product overview

**Times API** is a Python data pipeline (not a multi-service monorepo). It ingests three NYT APIs, transforms to slim NDJSON, loads to BigQuery via GCS + Cloud Function, models with dbt, and surfaces data in a Streamlit dashboard. There is no Docker Compose or local database.

### Dependency install (automatic)

On VM startup, `uv sync --group dev --group dbt --group dashboard` runs from the repo root. Ensure `uv` is on `PATH` (`$HOME/.local/bin`).

### One-time / manual setup (not in update script)

- **dbt profiles**: `profiles.yml` is gitignored. For `dbt parse`, `dbt debug`, or `dbt build`, create `~/.dbt/profiles.yml` with the `nyt_bigquery` profile (see `dbt_nyt_analytics/README.md` or `.github/workflows/dbt-pr.yml` for the OAuth or service-account template).
- **NYT API key**: repo-root `.env` with `NYTIMES_API_KEY=...` for live ingest (`uv run python -m most_popular.ingest`, etc.).
- **GCP credentials**: required for BigQuery, GCS upload, dbt against warehouse, and the Streamlit dashboard. Use `gcloud auth application-default login` or set `GCP_CREDENTIALS_PATH` in `dashboard/.env` (copy from `dashboard/.env.example`).

### Running quality checks

From repo root (matches CI in `.github/workflows/quality.yml`):

```bash
uv run ruff check .
uv run ruff format --check .
uv run mypy archive most_popular books tests
uv run pytest tests/ -v
shellcheck infra/*.sh
```

`shellcheck` is a system package (not installed by `uv sync`). Install with `apt` if missing.

### dbt (local)

```bash
uv sync --group dbt
uv run dbt system update          # first time / after uv sync
cd dbt_nyt_analytics
uv run dbt deps
uv run dbt parse                  # needs ~/.dbt/profiles.yml
uv run dbt build                  # needs BigQuery access
```

### Streamlit dashboard

```bash
uv sync --group dashboard
uv run streamlit run dashboard/pages/1_📰_Archive_Overview.py
```

Serves at `http://localhost:8501`. Without GCP credentials the app may start (HTTP 200) but charts will fail when querying BigQuery.

### Local pipeline demo (no external services)

Unit tests cover transform logic. For a quick end-to-end slice without API/GCP:

1. Place raw JSON under `most_popular_raw/<date>/viewed_30.json`
2. `uv run python -m most_popular.transform`
3. `uv run python -m most_popular.validate_ge`

Generated `*_raw/` and `*_slim/` dirs are gitignored.

### Long-running processes

Use tmux for dev servers, e.g. Streamlit on port 8501:

```bash
SESSION_NAME="streamlit-dashboard"
tmux -f /exec-daemon/tmux.portal.conf new-session -d -s "$SESSION_NAME" -c "/workspace" -- \
  bash -l -c 'export PATH="$HOME/.local/bin:$PATH"; uv run streamlit run dashboard/pages/1_📰_Archive_Overview.py --server.headless true'
```

### Gotchas

- All Python commands go through `uv run` from the repo root unless noted.
- `dbt` is the Fusion CLI (`dbt==2.0.0rc178`); run `uv run dbt system update` after fresh `uv sync --group dbt`.
- Pre-commit's `dbt-parse-manifest` hook requires `~/.dbt/profiles.yml` and runs from `dbt_nyt_analytics/`.
- Reinstalling deps with `uv sync` does not require restarting Streamlit if it is already running; restart if imports fail after dependency changes.
