#!/usr/bin/env bash
# Assemble a static dbt Docs site for GitHub Pages from Fusion build artifacts.
# index.html in this folder is vendored from dbt-core 1.10.8 static docs UI.
set -euo pipefail

PAGES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${PAGES_DIR}/.." && pwd)"
TARGET="${ROOT}/target"
SITE="${ROOT}/site"
DOCS_UI="${PAGES_DIR}/index.html"

for artifact in manifest.json catalog.json; do
  if [[ ! -f "${TARGET}/${artifact}" ]]; then
    echo "Missing ${TARGET}/${artifact}. Run dbt build --write-catalog first." >&2
    exit 1
  fi
done

if [[ ! -f "${DOCS_UI}" ]]; then
  echo "Missing ${DOCS_UI}." >&2
  exit 1
fi

mkdir -p "${SITE}"
cp "${TARGET}/manifest.json" "${TARGET}/catalog.json" "${SITE}/"
cp "${DOCS_UI}" "${SITE}/index.html"
echo "Static docs site ready in ${SITE}"
