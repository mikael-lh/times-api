"""
NYT Most Popular API – Pydantic model for slim article schema.

Used for validation when transforming; single source of truth
for the analysis-ready slim NDJSON output.
"""

from pydantic import BaseModel, ConfigDict, Field


class SlimMostPopularArticle(BaseModel):
    """
    Analysis-ready slim record for Most Popular articles.

    Used for validation when transforming; matches the slim NDJSON output.
    """

    model_config = ConfigDict(extra="ignore")

    id: int | None = None
    uri: str | None = None
    url: str | None = None
    asset_id: int | None = None
    source: str | None = None
    published_date: str | None = None
    updated: str | None = None
    section: str | None = None
    subsection: str | None = None
    byline: str | None = None
    type: str | None = None
    title: str | None = None
    abstract: str | None = None
    des_facet: list[str] = Field(default_factory=list)
    org_facet: list[str] = Field(default_factory=list)
    per_facet: list[str] = Field(default_factory=list)
    geo_facet: list[str] = Field(default_factory=list)
    media_count_by_type: dict[str, int] = Field(default_factory=dict)
    adx_keywords: str | None = None
