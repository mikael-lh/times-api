# AGENTS.md

Guidance for cloud agents working in this repository.

## Cursor Cloud specific instructions

### Product overview

**Times API** is a Python data pipeline (not a multi-service monorepo). It ingests three NYT APIs, transforms to slim NDJSON, loads to BigQuery via GCS + Cloud Function, models with dbt, and surfaces data in a Streamlit dashboard. There is no Docker Compose or local database.

### VM update script (automatic on Cloud Agent startup)

Cursor runs this from the repo root **before each Cloud Agent session** (after `git pull`). It is **not** committed as a shell file in the repo; it is configured in Cursor’s VM environment settings. You do not run this on your laptop unless you want the same effect manually.

```bash
uv sync --group dev --group dbt --group dashboard
cd dbt_nyt_analytics
uv run dbt deps
```

- **Line 1**: install/refresh the Python virtualenv (`.venv`) and all dependency groups.
- **Line 2–3**: install dbt package dependencies into `dbt_nyt_analytics/dbt_packages/`.

The update script does **not** create secrets, run tests, start Streamlit, or run `dbt build`. Ensure `uv` is on `PATH` (`$HOME/.local/bin`).

### Secrets and credentials (local vs Cloud VM)

`.env`, `profiles.yml`, and `dashboard/.env` are **gitignored**. They are **not** on the Cloud VM unless someone creates them there or Cursor injects values. Your laptop’s `.env` does **not** sync to the agent workspace.

| Goal | On your machine (local dev) | On a Cloud Agent VM |
|------|-----------------------------|---------------------|
| NYT API key | Create repo-root `.env`: `NYTIMES_API_KEY=...` | Add `NYTIMES_API_KEY` as a **Cursor Cloud secret**, or create `/workspace/.env` in the session (lost unless the VM snapshot retains it) |
| GCP for dbt / BQ / GCS | `gcloud auth application-default login` (interactive), or service-account JSON + `~/.dbt/profiles.yml` | Prefer **Cursor secrets** (e.g. `GCP_SA_KEY` JSON) and write `~/.dbt/profiles.yml` from the template in `.github/workflows/dbt-pr.yml`; `gcloud login` is usually **not** practical (no browser on the VM unless you use Desktop/login flows Cursor provides) |
| Streamlit + BigQuery | `dashboard/.env` from `dashboard/.env.example` (`GCP_PROJECT_ID`, optional `GCP_CREDENTIALS_PATH`) | Same: copy example and point at credentials available on the VM, or use application-default creds if configured |

**What works without any secrets:** `uv run pytest`, ruff/mypy, local transform + GE on sample files under `most_popular_raw/` (see below).

**What requires secrets:** live ingest (`*-ingest` modules), GCS upload, `dbt build`, dashboard queries against BigQuery.

Agents should ask you to add **Cursor Cloud secrets** when blocked; they cannot read secrets from your local repo checkout.

### One-time / manual setup on the VM (not in update script)

- **dbt profiles**: create `~/.dbt/profiles.yml` with the `nyt_bigquery` profile (see `dbt_nyt_analytics/README.md` or `.github/workflows/dbt-pr.yml`). Needed for `dbt parse`, `dbt debug`, and `dbt build`.
- **NYT API key**: only if running live ingest — see table above.
- **GCP**: only if running warehouse/dashboard/GCS paths — see table above.

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
