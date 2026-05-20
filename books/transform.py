"""
NYT Books API – transform raw overview to slim.

Reads raw JSON from books_raw/{published_date}/overview.json, flattens the
nested response (lists -> books), validates with Pydantic, and writes one
NDJSON record per (list, book) to books_slim/{published_date}/overview.ndjson.
"""

import json
from pathlib import Path

from pydantic import ValidationError

from books.models import SlimBestSeller

RAW_DIR = Path("books_raw")
SLIM_DIR = Path("books_slim")


def flatten_overview(raw_data: dict) -> list[dict]:
    """
    Flatten an overview response into one row per (list, book).

    The overview response has shape:
      results.published_date
      results.lists[].list_name_encoded
      results.lists[].display_name
      results.lists[].updated
      results.lists[].books[]

    Each book is stamped with the published_date and per-list metadata so
    the slim rows are self-contained for BigQuery.
    """
    results = raw_data.get("results") or {}
    published_date: str = results.get("published_date") or ""
    lists = results.get("lists") or []

    out: list[dict] = []
    for lst in lists:
        list_name_encoded = lst.get("list_name_encoded") or ""
        list_display_name = lst.get("display_name")
        list_updated = lst.get("updated")
        books = lst.get("books") or []

        for book in books:
            out.append(
                {
                    "published_date": published_date,
                    "list_name_encoded": list_name_encoded,
                    "list_display_name": list_display_name,
                    "list_updated": list_updated,
                    "rank": book.get("rank"),
                    "rank_last_week": book.get("rank_last_week"),
                    "weeks_on_list": book.get("weeks_on_list"),
                    "asterisk": book.get("asterisk"),
                    "dagger": book.get("dagger"),
                    "primary_isbn13": book.get("primary_isbn13"),
                    "title": book.get("title"),
                    "author": book.get("author"),
                    "contributor": book.get("contributor"),
                    "contributor_note": book.get("contributor_note"),
                    "publisher": book.get("publisher"),
                    "description": book.get("description"),
                    "book_image": book.get("book_image"),
                    "amazon_product_url": book.get("amazon_product_url"),
                    "age_group": book.get("age_group"),
                    "book_review_link": book.get("book_review_link"),
                    "sunday_review_link": book.get("sunday_review_link"),
                }
            )
    return out


def transform_file(raw_path: Path, overwrite: bool = False) -> bool:
    """
    Read a raw overview JSON, flatten, validate, write NDJSON.

    Args:
        raw_path: Path to raw overview JSON.
        overwrite: If True, overwrite existing slim file.

    Returns:
        True on success, False otherwise.
    """
    published_date = raw_path.parent.name
    slim_path = SLIM_DIR / published_date / "overview.ndjson"

    if not raw_path.exists():
        print(f"Skipping (raw file not found): {raw_path}")
        return False

    if slim_path.exists() and not overwrite:
        print(f"Skipping (slim already exists): {slim_path}")
        return True

    print(f"Transforming: {raw_path}")

    with open(raw_path) as f:
        raw_data = json.load(f)

    flattened = flatten_overview(raw_data)

    slim_path.parent.mkdir(parents=True, exist_ok=True)
    skipped = 0
    with open(slim_path, "w") as f:
        for rec in flattened:
            try:
                book = SlimBestSeller.model_validate(rec)
                f.write(book.model_dump_json() + "\n")
            except ValidationError as e:
                skipped += 1
                key = (rec.get("list_name_encoded"), rec.get("rank"))
                print(f"  Validation error (skipping) {key}: {e}")

    written = len(flattened) - skipped
    if skipped:
        print(f"Transformed {written} books ({skipped} skipped) -> {slim_path}")
    else:
        print(f"Transformed {written} books -> {slim_path}")

    return True


def transform_all(overwrite: bool = False) -> None:
    """Transform all raw overview files found in RAW_DIR."""
    raw_files = sorted(RAW_DIR.glob("*/overview.json"))

    if not raw_files:
        print(f"No raw files found in {RAW_DIR}. Run books ingest first.")
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


def main() -> None:
    transform_all()


if __name__ == "__main__":
    main()
