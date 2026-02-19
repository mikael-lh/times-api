#!/bin/bash
# NYT Most Popular API - Daily Ingestion Script
#
# This script runs the Most Popular API ingestion and transformation.
# Schedule with cron to run once daily, e.g.:
#   0 6 * * * /path/to/run_daily_ingestion.sh >> /var/log/nyt_ingestion.log 2>&1
#
# The above runs at 6:00 AM daily.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "========================================"
echo "NYT Most Popular Ingestion"
echo "Started: $(date -Iseconds)"
echo "========================================"

# Activate virtual environment if present
if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
fi

# Run ingestion
echo ""
echo "Step 1: Ingesting most viewed articles (last 30 days)..."
python3 ingest_most_popular.py

# Run transformation
echo ""
echo "Step 2: Transforming raw data to slim format..."
python3 transform_most_popular.py

echo ""
echo "========================================"
echo "Completed: $(date -Iseconds)"
echo "========================================"
