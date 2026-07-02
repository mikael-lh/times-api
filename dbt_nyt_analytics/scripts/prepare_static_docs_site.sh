#!/usr/bin/env bash
# Build a static dbt Docs site for GitHub Pages from Fusion artifacts.
# Fusion writes manifest.json + catalog.json; dbt-core ships the index.html SPA shell.
set -euo pipefail

TARGET_DIR="${1:-target}"
SITE_DIR="${2:-site}"
DBT_CORE_VERSION="${DBT_CORE_DOCS_UI_VERSION:-1.10.8}"

for artifact in manifest.json catalog.json; do
  if [[ ! -f "${TARGET_DIR}/${artifact}" ]]; then
    echo "Missing ${TARGET_DIR}/${artifact}. Run dbt build --write-catalog first." >&2
    exit 1
  fi
done

mkdir -p "${SITE_DIR}"
cp "${TARGET_DIR}/manifest.json" "${TARGET_DIR}/catalog.json" "${SITE_DIR}/"
touch "${SITE_DIR}/.nojekyll"

python -m pip install --quiet "dbt-core==${DBT_CORE_VERSION}"
INDEX_HTML="$(
  python - <<'PY'
from pathlib import Path
import dbt

print(Path(dbt.__file__).parent / "task" / "docs" / "index.html")
PY
)"
cp "${INDEX_HTML}" "${SITE_DIR}/index.html"
echo "Static docs site ready in ${SITE_DIR}"
