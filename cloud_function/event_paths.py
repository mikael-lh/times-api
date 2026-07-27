"""Pure helpers for Eventarc GCS path parsing (no env / GCP imports)."""

from __future__ import annotations

from typing import Any

_BUCKETS_MARKER = "/buckets/"
_OBJECTS_MARKER = "/objects/"


def relative_object_path(object_name: str, gcs_prefix: str) -> str | None:
    """
    Return the path relative to gcs_prefix when object_name is under that folder.

    Requires a directory boundary (prefix + "/") so names like
    "nyt-ingest-pr-123/..." are not treated as under "nyt-ingest".
    """
    folder = gcs_prefix + "/"
    if object_name.startswith(folder):
        return object_name[len(folder) :]
    return None


def bucket_and_object_from_event_data(data: Any) -> tuple[str | None, str | None]:
    """
    Extract (bucket, object_name) from Eventarc event data.

    Supports:
    - Direct GCS CloudEvents (bucket + name fields)
    - Cloud Audit Logs (protoPayload.resourceName)
    """
    if not isinstance(data, dict):
        return None, None

    bucket = data.get("bucket")
    name = data.get("name")
    if bucket and name:
        return str(bucket), str(name)

    proto = data.get("protoPayload") or {}
    resource_name = str(proto.get("resourceName") or "")
    if _BUCKETS_MARKER not in resource_name or _OBJECTS_MARKER not in resource_name:
        return None, None

    after_buckets = resource_name.split(_BUCKETS_MARKER, 1)[1]
    parsed_bucket, sep, object_name = after_buckets.partition(_OBJECTS_MARKER)
    if not sep or not parsed_bucket or not object_name:
        return None, None
    return parsed_bucket, object_name
