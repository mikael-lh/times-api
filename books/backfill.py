"""
NYT Books API – historical backfill script.

Iterates over every Sunday from START_DATE to END_DATE (inclusive) and calls
ingest_overview() for each, respecting the NYT rate limit (~5 req/min).
Safe to interrupt and resume: skip_existing=True means already-fetched weeks
are skipped instantly without hitting the API.

After ingestion, runs transform over all raw files so books_slim/ stays in sync.

Usage:
    # Full backfill from earliest available date to today:
    python -m books.backfill

    # Custom date range (useful for 500-req/day chunks):
    python -m books.backfill --start 2008-06-15 --end 2012-12-31

    # Dry-run: list dates that would be fetched without calling the API:
    python -m books.backfill --dry-run

    # Skip transform step (ingest only):
    python -m books.backfill --no-transform

Rate limit notes:
    NYT free tier: 500 requests/day, ~5 requests/minute.
    Default sleep between requests: 13 seconds (~4.6 req/min).
    Full backfill (2008-06-15 to present, ~930 weeks) takes ~2 days at this rate.
    Split into two runs using --start/--end to stay within the daily cap.
"""

import argparse
import sys
import time
from datetime import date, timedelta
from pathlib import Path

from books.ingest import ingest_overview
from books.transform import transform_file

EARLIEST_DATE = date(2008, 6, 15)  # First Sunday with data in the overview endpoint
SLEEP_SECONDS = 13  # 13s gap → ~4.6 req/min, safely under the 5 req/min limit
RAW_DIR = Path("books_raw")
SLIM_DIR = Path("books_slim")


def sundays_between(start: date, end: date) -> list[date]:
    """Return every Sunday in [start, end] inclusive."""
    # Advance start to the next Sunday if it isn't one already
    days_ahead = (6 - start.weekday()) % 7  # weekday(): Mon=0 … Sun=6
    first_sunday = start + timedelta(days=days_ahead)

    sundays = []
    current = first_sunday
    while current <= end:
        sundays.append(current)
        current += timedelta(weeks=1)
    return sundays


def run_backfill(
    start: date,
    end: date,
    dry_run: bool = False,
    run_transform: bool = True,
) -> None:
    dates = sundays_between(start, end)
    total = len(dates)

    print("Books API backfill")
    print(f"  Range  : {start} → {end}")
    print(f"  Weeks  : {total}")
    if not dry_run:
        est_minutes = (total * SLEEP_SECONDS) / 60
        print(
            f"  Est.   : ~{est_minutes:.0f} min at {SLEEP_SECONDS}s/request"
            " (skipped weeks are instant)"
        )
    print()

    if dry_run:
        print("DRY RUN — dates that would be fetched (file does not exist yet):")
        for d in dates:
            out_path = RAW_DIR / d.isoformat() / "overview.json"
            status = "SKIP (exists)" if out_path.exists() else "FETCH"
            print(f"  {d}  {status}")
        to_fetch = sum(1 for d in dates if not (RAW_DIR / d.isoformat() / "overview.json").exists())
        print(f"\nTotal: {total} dates ({to_fetch} to fetch)")
        return

    fetched = skipped = failed = 0

    for i, d in enumerate(dates, 1):
        out_path = RAW_DIR / d.isoformat() / "overview.json"
        already_exists = out_path.exists()

        print(f"[{i}/{total}] {d}", end="  ")

        if already_exists:
            print("SKIP (already exists)")
            skipped += 1
            continue

        success = ingest_overview(published_date=d.isoformat(), skip_existing=True)

        if success:
            fetched += 1
        else:
            failed += 1
            print(f"  WARNING: failed for {d} — continuing")

        # Only sleep after a real API call, not after skips
        if i < total:
            time.sleep(SLEEP_SECONDS)

    print()
    print(f"Ingestion complete: {fetched} fetched, {skipped} skipped, {failed} failed")

    if failed > 0:
        print(
            f"  {failed} date(s) failed — re-run to retry"
            " (skip_existing=True means successes won't be re-fetched)"
        )

    if not run_transform:
        print("Skipping transform (--no-transform)")
        return

    print()
    print("Running transform over all raw files...")
    raw_files = sorted(RAW_DIR.glob("*/overview.json"))
    t_ok = t_skip = t_fail = 0
    for raw_path in raw_files:
        date_str = raw_path.parent.name
        slim_path = SLIM_DIR / date_str / "overview.ndjson"
        if slim_path.exists():
            t_skip += 1
            continue
        result = transform_file(raw_path)
        if result:
            t_ok += 1
        else:
            t_fail += 1
            print(f"  Transform failed: {raw_path}")

    print(f"Transform complete: {t_ok} transformed, {t_skip} already existed, {t_fail} failed")

    if t_fail > 0 or failed > 0:
        sys.exit(1)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Backfill NYT Best Sellers overview data for all Sundays in a date range",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "--start",
        default=EARLIEST_DATE.isoformat(),
        help=f"Start date YYYY-MM-DD (default: {EARLIEST_DATE}, earliest with data)",
    )
    parser.add_argument(
        "--end",
        default=date.today().isoformat(),
        help="End date YYYY-MM-DD (default: today)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="List dates that would be fetched without calling the API",
    )
    parser.add_argument(
        "--no-transform",
        action="store_true",
        help="Skip the transform step after ingestion",
    )
    args = parser.parse_args()

    try:
        start = date.fromisoformat(args.start)
        end = date.fromisoformat(args.end)
    except ValueError as e:
        print(f"Error: invalid date — {e}")
        sys.exit(1)

    if start > end:
        print(f"Error: --start ({start}) is after --end ({end})")
        sys.exit(1)

    if start < EARLIEST_DATE:
        print(
            f"Warning: --start {start} is before the earliest date with data"
            f" ({EARLIEST_DATE}). Adjusting."
        )
        start = EARLIEST_DATE

    run_backfill(start=start, end=end, dry_run=args.dry_run, run_transform=not args.no_transform)


if __name__ == "__main__":
    main()
