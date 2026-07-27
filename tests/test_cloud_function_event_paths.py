"""Unit tests for Cloud Function Eventarc path helpers."""

import sys
from pathlib import Path

import pytest

_CF_DIR = Path(__file__).resolve().parents[1] / "cloud_function"
if str(_CF_DIR) not in sys.path:
    sys.path.insert(0, str(_CF_DIR))

from event_paths import (  # noqa: E402
    bucket_and_object_from_event_data,
    relative_object_path,
)


@pytest.mark.parametrize(
    ("object_name", "prefix", "expected"),
    [
        (
            "nyt-ingest/most_popular_slim/2026-07-27/viewed_30.ndjson",
            "nyt-ingest",
            "most_popular_slim/2026-07-27/viewed_30.ndjson",
        ),
        ("nyt-ingest/archive_slim/2019/01.ndjson", "nyt-ingest", "archive_slim/2019/01.ndjson"),
        ("nyt-ingest-pr-123/most_popular_slim/x.ndjson", "nyt-ingest", None),
        ("ci-pr-123/most_popular_slim/x.ndjson", "nyt-ingest", None),
        ("nyt-ingest", "nyt-ingest", None),
        (
            "nyt-ingest-pr-123/most_popular_slim/x.ndjson",
            "nyt-ingest-pr-123",
            "most_popular_slim/x.ndjson",
        ),
    ],
)
def test_relative_object_path(object_name: str, prefix: str, expected: str | None) -> None:
    assert relative_object_path(object_name, prefix) == expected


def test_bucket_and_object_from_direct_gcs_event() -> None:
    bucket, name = bucket_and_object_from_event_data(
        {"bucket": "my-bucket", "name": "nyt-ingest/most_popular_slim/a.ndjson"}
    )
    assert bucket == "my-bucket"
    assert name == "nyt-ingest/most_popular_slim/a.ndjson"


def test_bucket_and_object_from_audit_log_event() -> None:
    bucket, name = bucket_and_object_from_event_data(
        {
            "protoPayload": {
                "serviceName": "storage.googleapis.com",
                "methodName": "storage.objects.create",
                "resourceName": (
                    "projects/_/buckets/my-bucket/objects/"
                    "nyt-ingest/most_popular_slim/2026-07-27/viewed_30.ndjson"
                ),
            }
        }
    )
    assert bucket == "my-bucket"
    assert name == "nyt-ingest/most_popular_slim/2026-07-27/viewed_30.ndjson"


def test_bucket_and_object_rejects_invalid_payload() -> None:
    assert bucket_and_object_from_event_data(None) == (None, None)
    assert bucket_and_object_from_event_data({}) == (None, None)
    assert bucket_and_object_from_event_data({"protoPayload": {}}) == (None, None)
