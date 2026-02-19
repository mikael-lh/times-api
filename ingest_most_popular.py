"""
NYT Most Popular API – ingestion script.

Fetches most viewed articles for the last 30 days and saves raw JSON.
Designed to run once daily (via cron or scheduler).

API Endpoint: GET https://api.nytimes.com/svc/mostpopular/v2/viewed/{period}.json
Period options: 1, 7, or 30 (days)

Output: most_popular_raw/{date}/viewed_30.json
"""

import json
import os
from datetime import datetime
from pathlib import Path

import requests
from requests.exceptions import HTTPError
from dotenv import load_dotenv

load_dotenv()
API_KEY = os.getenv("NYTIMES_API_KEY")
BASE_URL = "https://api.nytimes.com/svc/mostpopular/v2"
RAW_DIR = Path("most_popular_raw")
PERIOD = 30


def fetch_most_viewed(period: int = PERIOD) -> dict | None:
    """
    Fetch most viewed articles for the given period (days).
    
    Args:
        period: Number of days (1, 7, or 30)
    
    Returns:
        Raw API response as dict, or None on error.
    """
    if not API_KEY:
        print("Error: Set NYTIMES_API_KEY in your .env file.")
        return None

    if period not in (1, 7, 30):
        print(f"Error: Invalid period {period}. Must be 1, 7, or 30.")
        return None

    url = f"{BASE_URL}/viewed/{period}.json"
    params = {"api-key": API_KEY}

    print(f"Requesting: {url}")
    try:
        response = requests.get(url, params=params, timeout=30)
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

    data = response.json()
    num_results = data.get("num_results", 0)
    print(f"Fetched {num_results} most viewed articles (last {period} days).")
    return data


def ingest_most_viewed(
    period: int = PERIOD,
    skip_existing: bool = False,
    date_str: str | None = None,
) -> bool:
    """
    Fetch most viewed articles and save raw JSON.

    Args:
        period: Number of days (1, 7, or 30)
        skip_existing: If True, skip if output file already exists
        date_str: Override date string for output path (default: today)

    Returns:
        True on success, False otherwise.
    """
    if date_str is None:
        date_str = datetime.now().strftime("%Y-%m-%d")

    out_path = RAW_DIR / date_str / f"viewed_{period}.json"

    if skip_existing and out_path.exists():
        print(f"Skipping (already exists): {out_path}")
        return True

    data = fetch_most_viewed(period)
    if data is None:
        return False

    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "w") as f:
        json.dump(data, f, indent=2)

    print(f"Ingested to {out_path}")
    return True


def main():
    """Main entry point: fetch most viewed articles for last 30 days."""
    print(f"=== NYT Most Popular Ingestion: {datetime.now().isoformat()} ===")
    success = ingest_most_viewed(period=PERIOD)
    if success:
        print("Ingestion completed successfully.")
    else:
        print("Ingestion failed.")
        exit(1)


if __name__ == "__main__":
    main()
