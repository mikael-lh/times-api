"""Tests for most_popular GE validation: validate_slim_ndjson, create_expectation_suite."""

import json

from most_popular.validate_ge import validate_slim_ndjson


def _write_ndjson(tmp_path, records, filename="viewed_30.ndjson"):
    """Write a list of dicts as NDJSON to a temp file."""
    path = tmp_path / filename
    with open(path, "w") as f:
        for rec in records:
            f.write(json.dumps(rec) + "\n")
    return path


def _make_valid_record(i=0):
    """Generate a single valid record matching real API patterns."""
    return {
        "id": 100000010678200 + i,
        "uri": f"nyt://article/{i}",
        "url": f"https://www.nytimes.com/2026/02/article-{i}.html",
        "asset_id": 100000010678200 + i,
        "source": "New York Times",
        "published_date": "2026-02-15",
        "updated": "2026-02-16 10:00:00",
        "section": "Arts",
        "subsection": "",
        "byline": "By Test Author",
        "type": "Article",
        "title": f"Test Article {i}",
        "abstract": "A test abstract.",
        "des_facet": ["Technology"],
        "org_facet": [],
        "per_facet": [],
        "geo_facet": [],
        "media_count_by_type": {"image": 1},
        "adx_keywords": "Technology",
    }


def _make_valid_records(n=20):
    return [_make_valid_record(i) for i in range(n)]


# ---- Happy path ----


def test_validate_ndjson_passes_with_valid_data(tmp_path):
    """Well-formed NDJSON with 20 records should pass all expectations."""
    path = _write_ndjson(tmp_path, _make_valid_records(20))
    result = validate_slim_ndjson(path)
    assert result.success is True
    assert len(result.results) > 0
    assert result.error_message is None


# ---- Null detection ----


def test_validate_fails_with_null_ids(tmp_path):
    records = _make_valid_records(20)
    for r in records:
        r["id"] = None
    path = _write_ndjson(tmp_path, records)
    result = validate_slim_ndjson(path)
    assert result.success is False
    failed_types = [r.expectation_config.type for r in result.results if not r.success]
    assert "expect_column_values_to_not_be_null" in failed_types


def test_validate_fails_with_null_urls(tmp_path):
    records = _make_valid_records(20)
    for r in records:
        r["url"] = None
    path = _write_ndjson(tmp_path, records)
    result = validate_slim_ndjson(path)
    assert result.success is False
    failed_types = [r.expectation_config.type for r in result.results if not r.success]
    assert "expect_column_values_to_not_be_null" in failed_types


def test_validate_fails_with_null_published_dates(tmp_path):
    records = _make_valid_records(20)
    for r in records:
        r["published_date"] = None
    path = _write_ndjson(tmp_path, records)
    result = validate_slim_ndjson(path)
    assert result.success is False


def test_validate_fails_with_null_titles(tmp_path):
    records = _make_valid_records(20)
    for r in records:
        r["title"] = None
    path = _write_ndjson(tmp_path, records)
    result = validate_slim_ndjson(path)
    assert result.success is False


# ---- Row count ----


def test_validate_fails_with_too_few_rows(tmp_path):
    path = _write_ndjson(tmp_path, _make_valid_records(5))
    result = validate_slim_ndjson(path)
    assert result.success is False
    failed_types = [r.expectation_config.type for r in result.results if not r.success]
    assert "expect_table_row_count_to_be_between" in failed_types


def test_validate_fails_with_too_many_rows(tmp_path):
    path = _write_ndjson(tmp_path, _make_valid_records(50))
    result = validate_slim_ndjson(path)
    assert result.success is False
    failed_types = [r.expectation_config.type for r in result.results if not r.success]
    assert "expect_table_row_count_to_be_between" in failed_types


# ---- Business rules ----


def test_validate_fails_with_wrong_source(tmp_path):
    records = _make_valid_records(20)
    records[0]["source"] = "Washington Post"
    path = _write_ndjson(tmp_path, records)
    result = validate_slim_ndjson(path)
    assert result.success is False
    failed_types = [r.expectation_config.type for r in result.results if not r.success]
    assert "expect_column_values_to_be_in_set" in failed_types


def test_validate_fails_with_invalid_date_format(tmp_path):
    records = _make_valid_records(20)
    records[0]["published_date"] = "02-15-2026"
    path = _write_ndjson(tmp_path, records)
    result = validate_slim_ndjson(path)
    assert result.success is False
    failed_types = [r.expectation_config.type for r in result.results if not r.success]
    assert "expect_column_values_to_match_regex" in failed_types


def test_validate_fails_with_future_dates(tmp_path):
    records = _make_valid_records(20)
    records[0]["published_date"] = "2099-12-31"
    path = _write_ndjson(tmp_path, records)
    result = validate_slim_ndjson(path)
    assert result.success is False
    assert "future" in result.error_message.lower()


def test_validate_fails_with_duplicate_ids(tmp_path):
    records = _make_valid_records(20)
    records[1]["id"] = records[0]["id"]
    path = _write_ndjson(tmp_path, records)
    result = validate_slim_ndjson(path)
    assert result.success is False
    failed_types = [r.expectation_config.type for r in result.results if not r.success]
    assert "expect_column_values_to_be_unique" in failed_types


# ---- Edge cases ----


def test_validate_fails_with_empty_file(tmp_path):
    path = tmp_path / "empty.ndjson"
    path.write_text("")
    result = validate_slim_ndjson(path)
    assert result.success is False


def test_validate_fails_with_nonexistent_file(tmp_path):
    path = tmp_path / "nonexistent.ndjson"
    result = validate_slim_ndjson(path)
    assert result.success is False
    assert "not found" in result.error_message.lower()
