"""Tests for archive transform: extract_slim_article, multimedia_counts_by_type, SlimArticle."""

from archive.models import SlimArticle
from archive.transform import extract_slim_article, multimedia_counts_by_type


def test_multimedia_counts_by_type_empty():
    assert multimedia_counts_by_type([]) == {}
    assert multimedia_counts_by_type(None) == {}


def test_multimedia_counts_by_type_counts():
    multimedia = [
        {"type": "image", "url": "a"},
        {"type": "image", "url": "b"},
        {"type": "video", "url": "c"},
        {},
        {"type": None},
    ]
    assert multimedia_counts_by_type(multimedia) == {"image": 2, "video": 1}


def test_extract_slim_article_minimal():
    doc = {}
    out = extract_slim_article(doc)
    assert out["_id"] is None
    assert out["uri"] is None
    assert out["headline_main"] is None
    assert out["keywords"] == []
    assert out["byline_person"] == []
    assert out["multimedia_count_by_type"] is None


def test_extract_slim_article_nested_headline_byline():
    doc = {
        "_id": "abc",
        "uri": "nyt://article/abc",
        "headline": {"main": "The Headline"},
        "byline": {"original": "By Jane Doe", "person": [{"firstname": "Jane", "lastname": "Doe"}]},
        "multimedia": [{"type": "image"}, {"type": "image"}],
    }
    out = extract_slim_article(doc)
    assert out["_id"] == "abc"
    assert out["uri"] == "nyt://article/abc"
    assert out["headline_main"] == "The Headline"
    assert out["byline_original"] == "By Jane Doe"
    assert out["byline_person"] == [{"firstname": "Jane", "lastname": "Doe"}]
    assert out["multimedia_count_by_type"] == {"image": 2}


def test_extract_slim_article_validates_to_slim_article():
    doc = {
        "_id": "123",
        "uri": "nyt://article/123",
        "pub_date": "2020-01-15",
        "section_name": "Business",
        "word_count": 500,
        "headline": {"main": "Test"},
        "byline": {},
        "keywords": [{"value": "Economy", "rank": 1}],
    }
    out = extract_slim_article(doc)
    article = SlimArticle.model_validate(out)
    assert article.article_id == "123"
    assert article.uri == "nyt://article/123"
    assert article.section_name == "Business"
    assert article.word_count == 500
    assert len(article.keywords) == 1
    assert article.keywords[0].value == "Economy"
