# AGENTS.md

Guidance for **Cursor Cloud Agents** working in this repository on the VM (`/workspace`).

Human local setup (clone, `.env`, `gcloud login`) lives in `README.md` — do not assume those files or credentials exist on the VM.

## Cursor Cloud specific instructions

### Product overview

**Times API** is a Python data pipeline (not a multi-service monorepo). It ingests three NYT APIs, transforms to slim NDJSON, loads to BigQuery via GCS + Cloud Function, models with dbt, and surfaces data in a Streamlit dashboard. There is no Docker Compose or local database.

### VM update script (automatic on Cloud Agent startup)

Cursor runs this from the repo root **before each Cloud Agent session** (after `git pull`). It is configured in Cursor’s VM environment settings, not as a committed shell file in the repo.

```bash
uv sync --group dev --group dbt --group dashboard
cd dbt_nyt_analytics
uv run dbt deps
```

- **Line 1**: install/refresh the Python virtualenv (`.venv`) and all dependency groups.
- **Line 2–3**: install dbt package dependencies into `dbt_nyt_analytics/dbt_packages/`.

The update script does **not** create secrets, run tests, start Streamlit, or run `dbt build`. Ensure `uv` is on `PATH` (`$HOME/.local/bin`).

### Secrets and credentials on the VM

`.env`, `profiles.yml`, and `dashboard/.env` are **gitignored** and are **not** present after checkout. Do not assume the user’s laptop secrets are available.

| Need | On the Cloud Agent VM |
|------|------------------------|
| NYT API key (live ingest) | Ask the user to add `NYTIMES_API_KEY` as a **Cursor Cloud secret**, or create `/workspace/.env` in-session if the value is provided |
| GCP / BigQuery / GCS | Ask for **Cursor Cloud secrets** (e.g. service-account JSON). Write `~/.dbt/profiles.yml` from the template in `.github/workflows/dbt-pr.yml`. Do not rely on `gcloud auth application-default login` unless the user completes an interactive login flow Cursor provides |
| Streamlit + BigQuery | Copy `dashboard/.env.example` → `dashboard/.env` and set `GCP_PROJECT_ID` plus credentials available on the VM |

**Works without secrets:** `uv run pytest`, ruff/mypy, in-repo transform + GE on sample files under `most_popular_raw/` (see below).

**Requires secrets:** live ingest modules, GCS upload, `dbt build`, dashboard queries against BigQuery.

When blocked, ask the user to add **Cursor Cloud secrets** — do not reference their local `.env` as if it were on the VM.

### One-time setup on the VM (not in update script)

- **dbt profiles**: create `~/.dbt/profiles.yml` with the `nyt_bigquery` profile (see `dbt_nyt_analytics/README.md` or `.github/workflows/dbt-pr.yml`) before `dbt parse`, `dbt debug`, or `dbt build`.
- **dbt Fusion CLI**: install with `uv sync --group dbt` from repo root (pinned in `pyproject.toml`).

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

### dbt (dev checkout on the VM)

```bash
cd dbt_nyt_analytics
uv run dbt deps                   # also run by VM update script
uv run dbt parse                  # needs ~/.dbt/profiles.yml
uv run dbt build                  # needs BigQuery access
```

### Streamlit dashboard

```bash
uv run streamlit run dashboard/pages/1_📰_Archive_Overview.py
```

Serves at `http://localhost:8501` on the VM. Without GCP credentials the app may start (HTTP 200) but charts fail when querying BigQuery.

### Pipeline demo without external services

For a quick end-to-end slice without NYT API or GCP:

1. Place raw JSON under `most_popular_raw/<date>/viewed_30.json`
2. `uv run python -m most_popular.transform`
3. `uv run python -m most_popular.validate_ge`

Generated `*_raw/` and `*_slim/` dirs are gitignored.

### Long-running processes

Use tmux for dev servers on the VM, e.g. Streamlit on port 8501:

```bash
SESSION_NAME="streamlit-dashboard"
tmux -f /exec-daemon/tmux.portal.conf new-session -d -s "$SESSION_NAME" -c "/workspace" -- \
  bash -l -c 'export PATH="$HOME/.local/bin:$PATH"; uv run streamlit run dashboard/pages/1_📰_Archive_Overview.py --server.headless true'
```

### Gotchas

- All Python commands use `uv run` from the repo root unless noted.
- `dbt` is the Fusion CLI (`dbt==2.0.0rc194` via `uv sync --group dbt`).
- Pre-commit's `dbt-parse-manifest` hook requires `~/.dbt/profiles.yml` and runs from `dbt_nyt_analytics/`.
- Reinstalling deps with `uv sync` does not require restarting Streamlit if it is already running; restart if imports fail after dependency changes.
