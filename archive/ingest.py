"""
NYT Archive API – ingestion only.

Fetches raw archive JSON per month and saves to archive_raw/YYYY/MM.json.
Uses 12 seconds sleep between API calls to respect rate limits.
Skips months that already have a raw file locally or in GCS (idempotent, safe to resume).
When GCS_BUCKET (and optional GCS_PREFIX) env vars are set, skips months that exist in GCS
so re-runs (e.g. after timeout) resume from where they left off.
"""

import json
import os
import re
import subprocess
import time
from pathlib import Path
from typing import Any, cast

import requests
from dotenv import load_dotenv
from requests.exceptions import HTTPError

load_dotenv()
API_KEY = os.getenv("NYTIMES_API_KEY")
BASE_URL = "https://api.nytimes.com/svc/archive/v1"
SLEEP_SECONDS = 13  # 12 seconds is the minimum per rate limits
RAW_DIR = Path("archive_raw")
GCS_BUCKET = os.getenv("GCS_BUCKET")
GCS_PREFIX = os.getenv("GCS_PREFIX", "nyt-ingest")
# Last 100 years (Archive API supports up to 2019 per spec)
START_YEAR = 1920
END_YEAR = 2020  # exclusive, so 1920..2019 (100 years)

# Pattern for gsutil ls output: .../archive_raw/YYYY/MM.json
GCS_ARCHIVE_PATTERN = re.compile(r"/(\d{4})/(\d{2})\.json$")


def list_existing_in_gcs() -> set[tuple[int, int]]:
    """List all (year, month) pairs that already exist in GCS (one listing for resume)."""
    existing: set[tuple[int, int]] = set()
    if not GCS_BUCKET:
        return existing
    prefix = f"gs://{GCS_BUCKET}/{GCS_PREFIX}/archive_raw/"
    result = subprocess.run(
        ["gsutil", "ls", "-r", prefix],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return existing
    for line in result.stdout.strip().splitlines():
        line = line.strip()
        if not line:
            continue
        m = GCS_ARCHIVE_PATTERN.search(line)
        if m:
            year, month = int(m.group(1)), int(m.group(2))
            if 1 <= month <= 12:
                existing.add((year, month))
    return existing


def list_existing_local() -> set[tuple[int, int]]:
    """List all (year, month) pairs that already exist under RAW_DIR."""
    existing: set[tuple[int, int]] = set()
    if not RAW_DIR.exists():
        return existing
    for year_dir in RAW_DIR.iterdir():
        if not year_dir.is_dir() or not year_dir.name.isdigit():
            continue
        year = int(year_dir.name)
        for path in year_dir.glob("*.json"):
            try:
                month = int(path.stem)
                if 1 <= month <= 12:
                    existing.add((year, month))
            except ValueError:
                continue
    return existing


def exists_in_gcs(year: int, month: int) -> bool:
    """Return True if archive_raw/YYYY/MM.json already exists in GCS (for resume)."""
    if not GCS_BUCKET:
        return False
    gcs_path = f"gs://{GCS_BUCKET}/{GCS_PREFIX}/archive_raw/{year}/{month:02d}.json"
    result = subprocess.run(
        ["gsutil", "stat", gcs_path],
        capture_output=True,
        text=True,
    )
    return result.returncode == 0


def fetch_archive(year: int, month: int) -> dict | None:
    """Fetch raw archive JSON for a given month. Returns None on error."""
    if not API_KEY:
        print("Error: Set NYTIMES_API_KEY in your .env file.")
        return None

    url = f"{BASE_URL}/{year}/{month}.json"
    params = {"api-key": API_KEY}

    print(f"Requesting: {url}")
    response = requests.get(url, params=params)

    if response.status_code == 401:
        print("Error: Unauthorized. Check that your API key is valid.")
        return None
    if response.status_code == 429:
        print("Error: Rate limit exceeded. Wait a minute or check your daily limit.")
        return None

    try:
        response.raise_for_status()
    except HTTPError as e:
        print(f"Error: HTTP {response.status_code} for {year}/{month:02d}: {e}")
        return None

    print(f" Fetched {year}/{month:02d}.")
    return cast(dict[str, Any], response.json())


def ingest_month(
    year: int, month: int, skip_existing: bool = True, skip_gcs_check: bool = False
) -> str:
    """
    Fetch one month from the Archive API and save raw JSON to RAW_DIR/year/month.json.
    Returns "skipped" when already exists, "fetched" on success, "error" on failure.
    If skip_existing is True, skips when the output file already exists locally or in GCS.
    If skip_gcs_check is True, only checks local path (caller has already filtered by GCS).
    """
    out_path = RAW_DIR / str(year) / f"{month:02d}.json"
    if skip_existing and out_path.exists():
        print(f"  Skipping {year}/{month:02d} (already exists: {out_path})")
        return "skipped"
    if skip_existing and not skip_gcs_check and exists_in_gcs(year, month):
        print(f"  Skipping {year}/{month:02d} (already in GCS)")
        return "skipped"

    data = fetch_archive(year, month)
    if data is None:
        return "error"

    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "w") as f:
        json.dump(data, f)

    print(f" Ingested {year}/{month:02d} to {out_path}.")

    docs_count = len(data.get("response", {}).get("docs", []))
    print(f"  Saved {docs_count} articles.")
    return "fetched"


def main():
    # Only months not already present locally or in GCS (one GCS list for resume)
    all_months = [(y, m) for y in range(START_YEAR, END_YEAR) for m in range(1, 13)]
    existing = list_existing_local() | list_existing_in_gcs()
    months_to_fetch = [(y, m) for (y, m) in all_months if (y, m) not in existing]
    if not months_to_fetch:
        print("All months already present locally or in GCS. Nothing to do.")
        return
    print(f"Found {len(existing)} months already present; {len(months_to_fetch)} months to fetch.")

    max_requests = int(os.getenv("ARCHIVE_MAX_REQUESTS", "0"))
    requests_this_run = 0
    previous_made_request = False

    for year, month in months_to_fetch:
        if max_requests > 0 and requests_this_run >= max_requests:
            print(f"Reached limit of {max_requests} requests this run. Re-run to resume.")
            break
        # Sleep only after an actual API call (rate limit), not when we only checked/skipped
        if previous_made_request:
            print(f"Sleeping {SLEEP_SECONDS} seconds before next request...")
            time.sleep(SLEEP_SECONDS)

        result = ingest_month(year, month, skip_gcs_check=True)
        previous_made_request = result in ("fetched", "error")
        if previous_made_request:
            requests_this_run += 1


if __name__ == "__main__":
    main()
