"""
NYT Most Popular API – Pydantic models for article schema.

Used for validation, JSON parsing, and a single source of truth
for the Most Popular articles returned by the API.
"""

from pydantic import BaseModel, ConfigDict, Field


class MediaMetadata(BaseModel):
    """Metadata for a single media rendition (different sizes)."""

    model_config = ConfigDict(extra="ignore")

    url: str | None = None
    format: str | None = None
    height: int | None = None
    width: int | None = None


class Media(BaseModel):
    """Media item (image, video) associated with an article."""

    model_config = ConfigDict(extra="ignore")

    type: str | None = None
    subtype: str | None = None
    caption: str | None = None
    copyright: str | None = None
    approved_for_syndication: int | None = None
    media_metadata: list[MediaMetadata] = Field(
        default_factory=list, alias="media-metadata"
    )


class MostPopularArticle(BaseModel):
    """
    A single article from the Most Popular API response.

    Contains all fields returned by the viewed/shared/emailed endpoints.
    """

    model_config = ConfigDict(populate_by_name=True, extra="ignore")

    uri: str | None = None
    url: str | None = None
    id: int | None = None
    asset_id: int | None = None
    source: str | None = None
    published_date: str | None = None
    updated: str | None = None
    section: str | None = None
    subsection: str | None = None
    nytdsection: str | None = None
    adx_keywords: str | None = None
    column: str | None = None
    byline: str | None = None
    type: str | None = None
    title: str | None = None
    abstract: str | None = None
    des_facet: list[str] = Field(default_factory=list)
    org_facet: list[str] = Field(default_factory=list)
    per_facet: list[str] = Field(default_factory=list)
    geo_facet: list[str] = Field(default_factory=list)
    media: list[Media] = Field(default_factory=list)
    eta_id: int | None = None


class MostPopularResponse(BaseModel):
    """
    Full response from the Most Popular API.

    Contains status, copyright info, result count, and the list of articles.
    """

    model_config = ConfigDict(extra="ignore")

    status: str | None = None
    copyright: str | None = None
    num_results: int | None = None
    results: list[MostPopularArticle] = Field(default_factory=list)
