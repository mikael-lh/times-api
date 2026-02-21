"""
NYT Most Popular API – transform raw to slim.

Reads raw JSON from most_popular_raw/, extracts analysis-ready fields,
writes validated NDJSON to most_popular_slim/{date}/viewed_30.ndjson.
"""

import json
from collections import Counter
from pathlib import Path

from pydantic import ValidationError

from most_popular.models import SlimMostPopularArticle

RAW_DIR = Path("most_popular_raw")
SLIM_DIR = Path("most_popular_slim")


def media_counts_by_type(media: list) -> dict:
    """Count media items by their 'type' field (e.g. image, video)."""
    if not media:
        return {}
    types = (m.get("type") for m in media if m.get("type"))
    return dict(Counter(types))


def extract_slim_most_popular(doc: dict) -> dict:
    """
    Extract analysis-ready fields from a raw Most Popular article doc.
    Includes media count by type.
    """
    media = doc.get("media") or []

    return {
        "id": doc.get("id"),
        "uri": doc.get("uri"),
        "url": doc.get("url"),
        "asset_id": doc.get("asset_id"),
        "source": doc.get("source"),
        "published_date": doc.get("published_date"),
        "updated": doc.get("updated"),
        "section": doc.get("section"),
        "subsection": doc.get("subsection"),
        "byline": doc.get("byline"),
        "type": doc.get("type"),
        "title": doc.get("title"),
        "abstract": doc.get("abstract"),
        "des_facet": doc.get("des_facet") or [],
        "org_facet": doc.get("org_facet") or [],
        "per_facet": doc.get("per_facet") or [],
        "geo_facet": doc.get("geo_facet") or [],
        "media_count_by_type": media_counts_by_type(media) or None,
        "adx_keywords": doc.get("adx_keywords"),
    }


def transform_file(raw_path: Path, overwrite: bool = False) -> bool:
    """
    Read raw JSON, validate, extract slim articles, write NDJSON.

    Args:
        raw_path: Path to raw JSON file
        overwrite: If True, overwrite existing slim file

    Returns:
        True on success, False otherwise.
    """
    date_str = raw_path.parent.name
    filename = raw_path.stem
    slim_path = SLIM_DIR / date_str / f"{filename}.ndjson"

    if not raw_path.exists():
        print(f"Skipping (raw file not found): {raw_path}")
        return False

    if slim_path.exists() and not overwrite:
        print(f"Skipping (slim already exists): {slim_path}")
        return True

    print(f"Transforming: {raw_path}")

    with open(raw_path) as f:
        raw_data = json.load(f)

    results = raw_data.get("results", [])
    slim_dicts = [extract_slim_most_popular(doc) for doc in results]

    slim_path.parent.mkdir(parents=True, exist_ok=True)
    skipped = 0
    with open(slim_path, "w") as f:
        for rec in slim_dicts:
            try:
                article = SlimMostPopularArticle.model_validate(rec)
                f.write(article.model_dump_json() + "\n")
            except ValidationError as e:
                skipped += 1
                print(f"  Validation error (skipping) id={rec.get('id')!r}: {e}")

    written = len(slim_dicts) - skipped
    if skipped:
        print(f"Transformed {written} articles ({skipped} skipped) -> {slim_path}")
    else:
        print(f"Transformed {written} articles -> {slim_path}")

    return True


def transform_all(overwrite: bool = False) -> None:
    """Transform all raw files found in RAW_DIR."""
    raw_files = sorted(RAW_DIR.glob("*/*.json"))

    if not raw_files:
        print(f"No raw files found in {RAW_DIR}. Run most_popular ingest first.")
        return

    print(f"Found {len(raw_files)} raw file(s) to transform.")
    success = 0
    failed = 0

    for raw_path in raw_files:
        if transform_file(raw_path, overwrite=overwrite):
            success += 1
        else:
            failed += 1

    print(f"\nTransformation complete: {success} succeeded, {failed} failed.")


def main():
    transform_all()


if __name__ == "__main__":
    main()
