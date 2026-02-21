"""Tests for most_popular transform: extract_slim_most_popular, media_counts_by_type."""

from most_popular.models import SlimMostPopularArticle
from most_popular.transform import extract_slim_most_popular, media_counts_by_type


def test_media_counts_by_type_empty():
    assert media_counts_by_type([]) == {}
    assert media_counts_by_type(None) == {}


def test_media_counts_by_type_counts():
    media = [{"type": "image"}, {"type": "image"}, {"type": "video"}]
    assert media_counts_by_type(media) == {"image": 2, "video": 1}


def test_extract_slim_most_popular_minimal():
    doc = {}
    out = extract_slim_most_popular(doc)
    assert out["id"] is None
    assert out["uri"] is None
    assert out["title"] is None
    assert out["des_facet"] == []
    assert out["media_count_by_type"] is None


def test_extract_slim_most_popular_full():
    doc = {
        "id": 12345,
        "uri": "nyt://article/12345",
        "title": "A Popular Article",
        "section": "Technology",
        "media": [{"type": "image"}, {"type": "image"}, {"type": "video"}],
        "des_facet": ["Computers", "Software"],
    }
    out = extract_slim_most_popular(doc)
    assert out["id"] == 12345
    assert out["title"] == "A Popular Article"
    assert out["section"] == "Technology"
    assert out["media_count_by_type"] == {"image": 2, "video": 1}
    assert out["des_facet"] == ["Computers", "Software"]


def test_extract_slim_most_popular_validates_to_slim_model():
    doc = {
        "id": 999,
        "uri": "nyt://article/999",
        "url": "https://example.com/999",
        "title": "Validated",
        "section": "World",
        "media": [{"type": "image"}, {"type": "image"}, {"type": "video"}],
        "des_facet": [],
    }
    out = extract_slim_most_popular(doc)
    article = SlimMostPopularArticle.model_validate(out)
    assert article.id == 999
    assert article.title == "Validated"
    assert article.section == "World"
    assert article.media_count_by_type == {"image": 2, "video": 1}
    assert article.des_facet == []
