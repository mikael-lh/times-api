"""Tests for books transform: flatten_overview + SlimBestSeller validation."""

import pytest
from pydantic import ValidationError

from books.models import SlimBestSeller
from books.transform import flatten_overview


def test_flatten_overview_empty():
    assert flatten_overview({}) == []
    assert flatten_overview({"results": {}}) == []
    assert flatten_overview({"results": {"lists": []}}) == []


def test_flatten_overview_single_list():
    raw = {
        "results": {
            "published_date": "2025-05-04",
            "lists": [
                {
                    "list_name_encoded": "hardcover-fiction",
                    "display_name": "Hardcover Fiction",
                    "updated": "WEEKLY",
                    "books": [
                        {
                            "rank": 1,
                            "rank_last_week": 1,
                            "weeks_on_list": 2,
                            "primary_isbn13": "9780593441299",
                            "title": "Great Big Beautiful Life",
                            "author": "Emily Henry",
                        }
                    ],
                }
            ],
        }
    }
    out = flatten_overview(raw)
    assert len(out) == 1
    row = out[0]
    assert row["published_date"] == "2025-05-04"
    assert row["list_name_encoded"] == "hardcover-fiction"
    assert row["list_display_name"] == "Hardcover Fiction"
    assert row["list_updated"] == "WEEKLY"
    assert row["rank"] == 1
    assert row["title"] == "Great Big Beautiful Life"
    assert row["author"] == "Emily Henry"


def test_flatten_overview_multiple_lists_and_books():
    raw = {
        "results": {
            "published_date": "2025-05-04",
            "lists": [
                {
                    "list_name_encoded": "hardcover-fiction",
                    "display_name": "Hardcover Fiction",
                    "updated": "WEEKLY",
                    "books": [{"rank": 1, "title": "A"}, {"rank": 2, "title": "B"}],
                },
                {
                    "list_name_encoded": "audio-fiction",
                    "display_name": "Audio Fiction",
                    "updated": "MONTHLY",
                    "books": [{"rank": 1, "title": "C"}],
                },
            ],
        }
    }
    out = flatten_overview(raw)
    assert len(out) == 3
    assert {r["list_name_encoded"] for r in out} == {"hardcover-fiction", "audio-fiction"}
    assert {(r["list_name_encoded"], r["rank"]) for r in out} == {
        ("hardcover-fiction", 1),
        ("hardcover-fiction", 2),
        ("audio-fiction", 1),
    }


def test_flatten_overview_validates_to_slim_model():
    raw = {
        "results": {
            "published_date": "2025-05-04",
            "lists": [
                {
                    "list_name_encoded": "hardcover-fiction",
                    "display_name": "Hardcover Fiction",
                    "updated": "WEEKLY",
                    "books": [
                        {
                            "rank": 1,
                            "primary_isbn13": "9780593441299",
                            "title": "Great Big Beautiful Life",
                            "author": "Emily Henry",
                        }
                    ],
                }
            ],
        }
    }
    rows = flatten_overview(raw)
    book = SlimBestSeller.model_validate(rows[0])
    assert book.rank == 1
    assert book.primary_isbn13 == "9780593441299"
    assert book.list_updated == "WEEKLY"
    assert book.title == "Great Big Beautiful Life"


def test_slim_model_rejects_invalid_list_updated():
    with pytest.raises(ValidationError):
        SlimBestSeller.model_validate(
            {
                "published_date": "2025-05-04",
                "list_name_encoded": "hardcover-fiction",
                "list_updated": "DAILY",
                "rank": 1,
            }
        )


def test_slim_model_missing_required_fields():
    with pytest.raises(ValidationError):
        SlimBestSeller.model_validate({"list_name_encoded": "hardcover-fiction", "rank": 1})
