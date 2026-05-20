"""
NYT Books API – Best Sellers overview ingestion script.

Fetches the Best Sellers overview (all lists for one week) and saves raw JSON.
Designed to run once per week (Thursday morning, after Wed 7pm ET publish).

API Endpoint: GET https://api.nytimes.com/svc/books/v3/lists/overview.json
Optional query: published_date=YYYY-MM-DD

Output: books_raw/{published_date}/overview.json

Note: published_date is the *print* publication date (Sunday). When called
without a date, the API returns the latest list and we use its `published_date`
field for the output path so the filename matches the data.
"""

import argparse
import json
import os
from datetime import datetime
from pathlib import Path
from typing import Any, cast

import requests
from dotenv import load_dotenv
from requests.exceptions import HTTPError

load_dotenv()
API_KEY = os.getenv("NYTIMES_API_KEY")
BASE_URL = "https://api.nytimes.com/svc/books/v3"
RAW_DIR = Path("books_raw")


def fetch_overview(published_date: str | None = None) -> dict | None:
    """
    Fetch the Best Sellers overview for a given print publication date.

    Args:
        published_date: YYYY-MM-DD print date; None for the current/latest list.

    Returns:
        Raw API response as dict, or None on error.
    """
    if not API_KEY:
        print("Error: Set NYTIMES_API_KEY in your .env file.")
        return None

    url = f"{BASE_URL}/lists/overview.json"
    params: dict[str, str] = {"api-key": API_KEY}
    if published_date:
        params["published_date"] = published_date

    label = published_date or "current"
    print(f"Requesting: {url} (published_date={label})")

    try:
        response = requests.get(url, params=params, timeout=60)
    except requests.exceptions.RequestException as e:
        print(f"Error: Request failed: {e}")
        return None

    if response.status_code == 401:
        print("Error: Unauthorized. Check that your API key is valid.")
        return None
    if response.status_code == 429:
        print("Error: Rate limit exceeded. Wait before retrying.")
        return None

    try:
        response.raise_for_status()
    except HTTPError as e:
        print(f"Error: HTTP {response.status_code}: {e}")
        return None

    data = cast(dict[str, Any], response.json())
    num_results = data.get("num_results", 0)
    print(f"Fetched overview with {num_results} books across all lists.")
    return data


def ingest_overview(
    published_date: str | None = None,
    skip_existing: bool = True,
) -> bool:
    """
    Fetch a Best Sellers overview and save raw JSON, keyed by the response's
    published_date so the file matches the data it contains.

    Args:
        published_date: YYYY-MM-DD print date; None for the current/latest list.
        skip_existing: If True, skip if output file already exists.

    Returns:
        True on success, False otherwise.
    """
    data = fetch_overview(published_date)
    if data is None:
        return False

    results = data.get("results", {}) or {}
    actual_date = results.get("published_date") or published_date
    if not actual_date:
        print("Error: Could not determine published_date from response.")
        return False

    out_path = RAW_DIR / actual_date / "overview.json"

    if skip_existing and out_path.exists():
        print(f"Skipping (already exists): {out_path}")
        return True

    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "w") as f:
        json.dump(data, f, indent=2)

    print(f"Ingested to {out_path}")
    return True


def main() -> None:
    """Entry point: fetch the latest Best Sellers overview, or a specific date."""
    parser = argparse.ArgumentParser(description="Ingest NYT Best Sellers overview")
    parser.add_argument(
        "--published-date",
        help="Print publication date (YYYY-MM-DD); omit for the latest list",
        default=None,
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Re-fetch even if the output file already exists",
    )
    args = parser.parse_args()

    print(f"=== NYT Best Sellers Ingestion: {datetime.now().isoformat()} ===")
    success = ingest_overview(
        published_date=args.published_date,
        skip_existing=not args.overwrite,
    )
    if success:
        print("Ingestion completed successfully.")
    else:
        print("Ingestion failed.")
        exit(1)


if __name__ == "__main__":
    main()
