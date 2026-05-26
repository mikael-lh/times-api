"""
NYT Books API – Great Expectations validation for slim NDJSON.

Minimal dataset-level checks per project convention: catch structural and
distributional issues before GCS upload. Per-record types are handled by
Pydantic; referential/semantic checks live in dbt tests.

GE handles:
- non-empty file
- (published_date, list_name_encoded, rank, list_updated) uniqueness
- list_updated in {WEEKLY, MONTHLY}
- ISBN-13 format
- published_date YYYY-MM-DD format
"""

import argparse
import sys
from pathlib import Path

import great_expectations as gx
import pandas as pd

SLIM_DIR = Path("books_slim")


def create_expectation_suite(context: gx.data_context.EphemeralDataContext) -> gx.ExpectationSuite:
    """
    Define dataset-level expectations for best_sellers slim NDJSON.

    Based on SlimBestSeller schema and the Books API response contract:
    - Row count: 100-400 (overview returns ~250 books across all lists)
    - Uniqueness: (published_date, list_name_encoded, rank, list_updated) composite is unique
    - Required fields: published_date, list_name_encoded, rank, title
    - Whitelist: list_updated in {WEEKLY, MONTHLY}
    - Format: published_date YYYY-MM-DD, primary_isbn13 13 digits
    """
    suite = context.suites.add(gx.ExpectationSuite(name="best_sellers_slim_suite"))

    suite.add_expectation(
        gx.expectations.ExpectTableRowCountToBeBetween(min_value=100, max_value=400)
    )

    for col in ("published_date", "list_name_encoded", "rank", "title"):
        suite.add_expectation(gx.expectations.ExpectColumnValuesToNotBeNull(column=col))

    suite.add_expectation(
        gx.expectations.ExpectColumnValuesToBeInSet(
            column="list_updated", value_set=["WEEKLY", "MONTHLY"]
        )
    )
    suite.add_expectation(
        gx.expectations.ExpectColumnValuesToMatchRegex(
            column="published_date", regex=r"^\d{4}-\d{2}-\d{2}$"
        )
    )
    suite.add_expectation(
        gx.expectations.ExpectColumnValuesToMatchRegex(
            column="primary_isbn13",
            regex=r"^\d{13}$",
            mostly=0.95,
        )
    )

    suite.add_expectation(
        gx.expectations.ExpectCompoundColumnsToBeUnique(
            column_list=["published_date", "list_name_encoded", "rank", "list_updated"]
        )
    )

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

    return {
        "success": bool(checkpoint_result.success),
        "results": expectation_results,
        "error_message": None if checkpoint_result.success else "GE expectations failed",
    }


def main() -> None:
    """CLI entry point: validate slim NDJSON with detailed error reporting."""
    parser = argparse.ArgumentParser(
        description="Validate best_sellers slim NDJSON with Great Expectations"
    )
    parser.add_argument("--file", help="Path to NDJSON file (default: auto-detect latest)")
    args = parser.parse_args()

    if args.file:
        path = Path(args.file)
    else:
        files = sorted(SLIM_DIR.glob("*/overview.ndjson"))
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
