"""
NYT Archive API – Pydantic models for slim article schema.

Used for validation, JSON parsing, and a single source of truth
for the analysis-ready slim record (and nested keyword/byline-person).
"""

from pydantic import BaseModel, ConfigDict, Field


class Keyword(BaseModel):
    """One keyword in the article's keywords list (topic/subject)."""

    name: str | None = None
    value: str | None = None
    rank: int | None = None
    major: str | None = None


class BylinePerson(BaseModel):
    """One person in the article's byline (author)."""

    model_config = ConfigDict(extra="ignore")

    firstname: str | None = None
    lastname: str | None = None
    middlename: str | None = None
    qualifier: str | None = None


class SlimArticle(BaseModel):
    """
    Analysis-ready slim article record.

    Matches the slim schema: identifiers, dimensions, text,
    keywords, byline_person, multimedia_count_by_type.
    """

    model_config = ConfigDict(populate_by_name=True)

    article_id: str | None = Field(None, alias="_id")
    uri: str | None = None
    pub_date: str | None = None
    section_name: str | None = None
    news_desk: str | None = None
    type_of_material: str | None = None
    document_type: str | None = None
    word_count: int | None = None
    web_url: str | None = None
    headline_main: str | None = None
    byline_original: str | None = None
    abstract: str | None = None
    snippet: str | None = None
    keywords: list[Keyword] = Field(default_factory=list)
    byline_person: list[BylinePerson] = Field(default_factory=list)
    multimedia_count_by_type: dict[str, int] | None = None  # None instead of {} for BigQuery compatibility
