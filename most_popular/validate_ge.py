"""
NYT Most Popular API – Great Expectations validation for slim NDJSON.

Dataset-level quality checks that complement Pydantic's record-level validation.
Runs after transform, before GCS upload, to catch data quality issues before
they propagate to BigQuery.

Pydantic handles: type checking per record (int, str, list, etc.)
GE handles: completeness, business rules, row counts, distributions across all records.
"""

import argparse
import sys
from datetime import datetime
from pathlib import Path

import great_expectations as gx
import pandas as pd

SLIM_DIR = Path("most_popular_slim")


def create_expectation_suite(context: gx.data_context.EphemeralDataContext) -> gx.ExpectationSuite:
    """
    Define dataset-level expectations for most_popular slim NDJSON.

    Based on SlimMostPopularArticle schema and historical API response patterns:
    - Row count: 15-30 (API typically returns ~20 articles)
    - Completeness: id, url, published_date, title must not be null
    - Business rules: source must be "New York Times", date format YYYY-MM-DD
    - Uniqueness: no duplicate article IDs
    """
    suite = context.suites.add(gx.ExpectationSuite(name="most_popular_slim_suite"))

    suite.add_expectation(
        gx.expectations.ExpectTableRowCountToBeBetween(min_value=15, max_value=30)
    )

    for col in ("id", "url", "published_date", "title"):
        suite.add_expectation(gx.expectations.ExpectColumnValuesToNotBeNull(column=col))

    suite.add_expectation(
        gx.expectations.ExpectColumnValuesToBeInSet(column="source", value_set=["New York Times"])
    )
    suite.add_expectation(
        gx.expectations.ExpectColumnValuesToMatchRegex(
            column="published_date", regex=r"^\d{4}-\d{2}-\d{2}$"
        )
    )
    suite.add_expectation(gx.expectations.ExpectColumnValuesToBeUnique(column="id"))

    return suite


def validate_slim_ndjson(ndjson_path: Path) -> dict:
    """
    Validate a slim NDJSON file using Great Expectations.

    Reads the file as a pandas DataFrame, runs dataset-level expectations,
    and returns a dict with success, results, and optional error_message.
    """
    if not ndjson_path.exists():
        return {"success": False, "results": [], "error_message": f"File not found: {ndjson_path}"}

    try:
        df = pd.read_json(ndjson_path, lines=True)
    except ValueError as e:
        return {"success": False, "results": [], "error_message": f"Failed to read NDJSON: {e}"}

    if df.empty:
        return {"success": False, "results": [], "error_message": f"Empty file: {ndjson_path}"}

    context = gx.get_context(mode="ephemeral")

    ds = context.data_sources.add_pandas(name="slim_ds")
    asset = ds.add_dataframe_asset(name="slim_asset")
    batch_def = asset.add_batch_definition_whole_dataframe("slim_batch")

    suite = create_expectation_suite(context)

    vd = context.validation_definitions.add(
        gx.ValidationDefinition(name="slim_vd", data=batch_def, suite=suite)
    )
    checkpoint = context.checkpoints.add(gx.Checkpoint(name="slim_cp", validation_definitions=[vd]))

    checkpoint_result = checkpoint.run(batch_parameters={"dataframe": df})

    expectation_results = []
    for run_result in checkpoint_result.run_results.values():
        expectation_results.extend(run_result.results)

    # Post-GE check: published_date not in the future
    today = datetime.now().strftime("%Y-%m-%d")
    str_dates = [v for v in df["published_date"] if isinstance(v, str) and v > today]
    future_date_success = len(str_dates) == 0

    return {
        "success": bool(checkpoint_result.success) and future_date_success,
        "results": expectation_results,
        "error_message": None
        if future_date_success
        else f"Found {len(str_dates)} article(s) with future published_date",
    }


def main() -> None:
    """CLI entry point: validate slim NDJSON with detailed error reporting."""
    parser = argparse.ArgumentParser(
        description="Validate most_popular slim NDJSON with Great Expectations"
    )
    parser.add_argument("--file", help="Path to NDJSON file (default: auto-detect latest)")
    args = parser.parse_args()

    if args.file:
        path = Path(args.file)
    else:
        files = sorted(SLIM_DIR.glob("*/viewed_30.ndjson"))
        if not files:
            print(f"No NDJSON files found in {SLIM_DIR}")
            sys.exit(1)
        path = files[-1]

    print(f"Validating: {path}")
    result = validate_slim_ndjson(path)

    if result["error_message"]:
        print(f"\n  Error: {result['error_message']}")

    if result["success"]:
        print(f"VALIDATION PASSED ({len(result['results'])} expectations)")
    else:
        print("VALIDATION FAILED\n")
        print("Failed expectations:")
        for exp_result in result["results"]:
            if not exp_result.success:
                exp_type = exp_result.expectation_config.type
                kwargs = {
                    k: v for k, v in exp_result.expectation_config.kwargs.items() if k != "batch_id"
                }
                print(f"  - {exp_type}")
                print(f"    Config: {kwargs}")
                if exp_result.result:
                    print(f"    Result: {exp_result.result}")
        sys.exit(1)


if __name__ == "__main__":
    main()
