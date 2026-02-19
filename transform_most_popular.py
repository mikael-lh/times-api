"""
NYT Most Popular API – transform raw to slim.

Reads raw JSON from most_popular_raw/, extracts analysis-ready fields,
writes validated NDJSON to most_popular_slim/{date}/viewed_30.ndjson.
"""

import json
from collections import Counter
from pathlib import Path

from pydantic import ValidationError

from most_popular_models import MostPopularArticle, MostPopularResponse

RAW_DIR = Path("most_popular_raw")
SLIM_DIR = Path("most_popular_slim")


class SlimMostPopularArticle:
    """
    Slim representation of a Most Popular article for analytics.

    Extracts key fields and computes derived metrics.
    """

    @staticmethod
    def from_article(article: MostPopularArticle) -> dict:
        """Convert a MostPopularArticle to a slim dict."""
        media_counts = Counter(m.type for m in article.media if m.type)

        return {
            "id": article.id,
            "uri": article.uri,
            "url": article.url,
            "asset_id": article.asset_id,
            "source": article.source,
            "published_date": article.published_date,
            "updated": article.updated,
            "section": article.section,
            "subsection": article.subsection,
            "byline": article.byline,
            "type": article.type,
            "title": article.title,
            "abstract": article.abstract,
            "des_facet": article.des_facet,
            "org_facet": article.org_facet,
            "per_facet": article.per_facet,
            "geo_facet": article.geo_facet,
            "media_count_by_type": dict(media_counts),
            "adx_keywords": article.adx_keywords,
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

    try:
        response = MostPopularResponse.model_validate(raw_data)
    except ValidationError as e:
        print(f"Error: Invalid response structure: {e}")
        return False

    slim_path.parent.mkdir(parents=True, exist_ok=True)
    skipped = 0
    written = 0

    with open(slim_path, "w") as f:
        for article in response.results:
            try:
                slim_dict = SlimMostPopularArticle.from_article(article)
                f.write(json.dumps(slim_dict) + "\n")
                written += 1
            except Exception as e:
                skipped += 1
                print(f"  Error processing article id={article.id}: {e}")

    if skipped:
        print(f"Transformed {written} articles ({skipped} skipped) -> {slim_path}")
    else:
        print(f"Transformed {written} articles -> {slim_path}")

    return True


def transform_all(overwrite: bool = False) -> None:
    """Transform all raw files found in RAW_DIR."""
    raw_files = sorted(RAW_DIR.glob("*/*.json"))

    if not raw_files:
        print(f"No raw files found in {RAW_DIR}. Run ingest_most_popular.py first.")
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
