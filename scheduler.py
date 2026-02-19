"""
NYT Most Popular API – Daily Scheduler.

Runs ingestion and transformation once per day using the schedule library.
Alternative to cron for environments where cron isn't available.

Usage:
    python scheduler.py

Configuration:
    - RUN_TIME: Time to run daily (HH:MM format, 24-hour)
    - Set NYTIMES_API_KEY in .env file
"""

import time
from datetime import datetime

import schedule

from ingest_most_popular import ingest_most_viewed, PERIOD
from transform_most_popular import transform_all

RUN_TIME = "06:00"


def daily_job():
    """Run the daily ingestion and transformation pipeline."""
    print(f"\n{'='*50}")
    print(f"Daily job started: {datetime.now().isoformat()}")
    print("=" * 50)

    print("\nStep 1: Ingesting most viewed articles...")
    success = ingest_most_viewed(period=PERIOD)

    if success:
        print("\nStep 2: Transforming to slim format...")
        transform_all()
        print("\nDaily job completed successfully.")
    else:
        print("\nIngestion failed. Skipping transformation.")

    print("=" * 50)


def run_now_and_schedule():
    """Run immediately, then schedule for daily execution."""
    print(f"NYT Most Popular Scheduler started at {datetime.now().isoformat()}")
    print(f"Scheduled to run daily at {RUN_TIME}")
    print("Running initial job now...\n")

    daily_job()

    schedule.every().day.at(RUN_TIME).do(daily_job)

    print(f"\nScheduler active. Next run at {RUN_TIME} daily.")
    print("Press Ctrl+C to stop.\n")

    while True:
        schedule.run_pending()
        time.sleep(60)


def main():
    """Entry point for the scheduler."""
    try:
        run_now_and_schedule()
    except KeyboardInterrupt:
        print("\nScheduler stopped.")


if __name__ == "__main__":
    main()
