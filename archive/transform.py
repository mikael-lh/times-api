"""
NYT Archive API – transform raw to slim.

Reads raw JSON from archive_raw/, extracts analysis-ready fields
(including byline.person and multimedia counts by type), writes NDJSON
to archive_slim/YYYY/MM.ndjson.
"""

import json
from collections import Counter
from pathlib import Path

from pydantic import ValidationError

from archive.models import SlimArticle

RAW_DIR = Path("archive_raw")
SLIM_DIR = Path("archive_slim")


def multimedia_counts_by_type(multimedia: list) -> dict:
    """Count multimedia items by their 'type' field (e.g. image, video)."""
    if not multimedia:
        return {}
    types = (m.get("type") for m in multimedia if m.get("type"))
    return dict(Counter(types))


def extract_slim_article(doc: dict) -> dict:
    """
    Extract analysis-ready fields from a raw article doc.
    Includes byline.person and multimedia counts by type.
    """
    headline = doc.get("headline") or {}
    byline = doc.get("byline") or {}
    multimedia = doc.get("multimedia") or []

    return {
        "_id": doc.get("_id"),
        "uri": doc.get("uri"),
        "pub_date": doc.get("pub_date"),
        "section_name": doc.get("section_name"),
        "news_desk": doc.get("news_desk"),
        "type_of_material": doc.get("type_of_material"),
        "document_type": doc.get("document_type"),
        "word_count": doc.get("word_count"),
        "web_url": doc.get("web_url"),
        "headline_main": headline.get("main"),
        "byline_original": byline.get("original"),
        "abstract": doc.get("abstract"),
        "snippet": doc.get("snippet"),
        "keywords": doc.get("keywords") or [],
        "byline_person": byline.get("person") or [],
        "multimedia_count_by_type": multimedia_counts_by_type(multimedia) or None,
    }


def transform_month(year: int, month: int, overwrite: bool = False) -> bool:
    """
    Read raw JSON for one month, extract slim articles, write NDJSON.
    Returns True on success, False if raw file missing.
    """
    raw_path = RAW_DIR / str(year) / f"{month:02d}.json"
    slim_path = SLIM_DIR / str(year) / f"{month:02d}.ndjson"

    if not raw_path.exists():
        print(f"  Skipping {year}/{month:02d} (raw file not found: {raw_path})")
        return False

    if slim_path.exists() and not overwrite:
        print(f"  Skipping {year}/{month:02d} (slim already exists: {slim_path})")
        return True

    with open(raw_path) as f:
        data = json.load(f)

    docs = data.get("response", {}).get("docs", [])
    slim_dicts = [extract_slim_article(doc) for doc in docs]

    slim_path.parent.mkdir(parents=True, exist_ok=True)
    skipped = 0
    with open(slim_path, "w") as f:
        for rec in slim_dicts:
            try:
                article = SlimArticle.model_validate(rec)
                f.write(article.model_dump_json() + "\n")
            except ValidationError as e:
                skipped += 1
                print(f"  Validation error (skipping) _id={rec.get('_id')!r}: {e}")

    if skipped:
        print(f"  Transformed {year}/{month:02d} ({skipped} record(s) skipped).")
    else:
        print(f"  Transformed {year}/{month:02d}.")
    return True


def main():
    # Process all raw files found (or specify a list like ingest)
    raw_files = sorted(RAW_DIR.glob("*/*.json"))
    if not raw_files:
        print(f"No raw files found in {RAW_DIR}. Run archive ingest first.")
        return

    for raw_path in raw_files:
        year = int(raw_path.parent.name)
        month = int(raw_path.stem)
        transform_month(year, month)


if __name__ == "__main__":
    main()
