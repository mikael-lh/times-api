"""Tests for books GE validation: validate_slim_ndjson, create_expectation_suite."""

import json

from books.validate_ge import validate_slim_ndjson


def _write_ndjson(tmp_path, records, filename="overview.ndjson"):
    """Write a list of dicts as NDJSON to a temp file."""
    path = tmp_path / filename
    with open(path, "w") as f:
        for rec in records:
            f.write(json.dumps(rec) + "\n")
    return path


def _make_valid_record(i: int = 0) -> dict:
    """Generate one valid best-seller row matching the SlimBestSeller schema."""
    return {
        "published_date": "2026-05-18",
        "list_name_encoded": "hardcover-fiction",
        "list_display_name": "Hardcover Fiction",
        "list_updated": "WEEKLY",
        "rank": i + 1,
        "rank_last_week": i,
        "weeks_on_list": 3,
        "primary_isbn13": f"978000000{i:04d}",
        "title": f"Test Book {i}",
        "author": "Test Author",
        "contributor": "by Test Author",
        "description": "A test book.",
        "publisher": "Test Publisher",
        "buy_links": None,
        "book_image": None,
        "book_review_link": None,
        "first_chapter_link": None,
        "sunday_review_link": None,
        "article_chapter_link": None,
        "age_group": "",
        "price": "",
    }


def _make_valid_records(n: int = 150) -> list[dict]:
    return [_make_valid_record(i) for i in range(n)]


# ---- Happy path ----


def test_validate_ndjson_passes_with_valid_data(tmp_path):
    """Well-formed NDJSON with 150 records should pass all expectations."""
    path = _write_ndjson(tmp_path, _make_valid_records(150))
    result = validate_slim_ndjson(path)
    assert result["success"] is True
    assert len(result["results"]) > 0
    assert result["error_message"] is None


# ---- Row count ----


def test_validate_fails_with_too_few_rows(tmp_path):
    path = _write_ndjson(tmp_path, _make_valid_records(50))
    result = validate_slim_ndjson(path)
    assert result["success"] is False
    failed_types = [r.expectation_config.type for r in result["results"] if not r.success]
    assert "expect_table_row_count_to_be_between" in failed_types


def test_validate_fails_with_too_many_rows(tmp_path):
    path = _write_ndjson(tmp_path, _make_valid_records(500))
    result = validate_slim_ndjson(path)
    assert result["success"] is False
    failed_types = [r.expectation_config.type for r in result["results"] if not r.success]
    assert "expect_table_row_count_to_be_between" in failed_types


# ---- Null detection ----


def test_validate_fails_with_null_published_date(tmp_path):
    records = _make_valid_records(150)
    for r in records:
        r["published_date"] = None
    path = _write_ndjson(tmp_path, records)
    result = validate_slim_ndjson(path)
    assert result["success"] is False
    failed_types = [r.expectation_config.type for r in result["results"] if not r.success]
    assert "expect_column_values_to_not_be_null" in failed_types


def test_validate_fails_with_null_list_name_encoded(tmp_path):
    records = _make_valid_records(150)
    for r in records:
        r["list_name_encoded"] = None
    path = _write_ndjson(tmp_path, records)
    result = validate_slim_ndjson(path)
    assert result["success"] is False
    failed_types = [r.expectation_config.type for r in result["results"] if not r.success]
    assert "expect_column_values_to_not_be_null" in failed_types


def test_validate_fails_with_null_rank(tmp_path):
    records = _make_valid_records(150)
    for r in records:
        r["rank"] = None
    path = _write_ndjson(tmp_path, records)
    result = validate_slim_ndjson(path)
    assert result["success"] is False
    failed_types = [r.expectation_config.type for r in result["results"] if not r.success]
    assert "expect_column_values_to_not_be_null" in failed_types


def test_validate_fails_with_null_titles(tmp_path):
    records = _make_valid_records(150)
    for r in records:
        r["title"] = None
    path = _write_ndjson(tmp_path, records)
    result = validate_slim_ndjson(path)
    assert result["success"] is False
    failed_types = [r.expectation_config.type for r in result["results"] if not r.success]
    assert "expect_column_values_to_not_be_null" in failed_types


# ---- Business rules ----


def test_validate_fails_with_invalid_list_updated(tmp_path):
    records = _make_valid_records(150)
    records[0]["list_updated"] = "DAILY"
    path = _write_ndjson(tmp_path, records)
    result = validate_slim_ndjson(path)
    assert result["success"] is False
    failed_types = [r.expectation_config.type for r in result["results"] if not r.success]
    assert "expect_column_values_to_be_in_set" in failed_types


def test_validate_fails_with_invalid_date_format(tmp_path):
    records = _make_valid_records(150)
    records[0]["published_date"] = "05-18-2026"
    path = _write_ndjson(tmp_path, records)
    result = validate_slim_ndjson(path)
    assert result["success"] is False
    failed_types = [r.expectation_config.type for r in result["results"] if not r.success]
    assert "expect_column_values_to_match_regex" in failed_types


def test_validate_fails_with_duplicate_composite_key(tmp_path):
    records = _make_valid_records(150)
    # Force duplicate (published_date, list_name_encoded, rank)
    records[1]["published_date"] = records[0]["published_date"]
    records[1]["list_name_encoded"] = records[0]["list_name_encoded"]
    records[1]["rank"] = records[0]["rank"]
    path = _write_ndjson(tmp_path, records)
    result = validate_slim_ndjson(path)
    assert result["success"] is False
    failed_types = [r.expectation_config.type for r in result["results"] if not r.success]
    assert "expect_compound_columns_to_be_unique" in failed_types


# ---- Edge cases ----


def test_validate_fails_with_empty_file(tmp_path):
    path = tmp_path / "overview.ndjson"
    path.write_text("")
    result = validate_slim_ndjson(path)
    assert result["success"] is False


def test_validate_fails_with_nonexistent_file(tmp_path):
    path = tmp_path / "nonexistent.ndjson"
    result = validate_slim_ndjson(path)
    assert result["success"] is False
    assert "not found" in result["error_message"].lower()
