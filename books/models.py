"""
NYT Books API – Pydantic model for slim Best Sellers schema.

Used for validation when transforming; single source of truth
for the analysis-ready slim NDJSON output.
"""

from typing import Literal

from pydantic import BaseModel, ConfigDict


class SlimBestSeller(BaseModel):
    """
    Analysis-ready slim record for a Best Sellers list entry.

    One row per (published_date, list_name_encoded, rank, list_updated).
    """

    model_config = ConfigDict(extra="ignore")

    published_date: str
    list_name_encoded: str
    list_display_name: str | None = None
    list_updated: Literal["WEEKLY", "MONTHLY"] | None = None

    rank: int
    rank_last_week: int | None = None
    weeks_on_list: int | None = None
    asterisk: int | None = None
    dagger: int | None = None

    primary_isbn13: str | None = None
    title: str | None = None
    author: str | None = None
    contributor: str | None = None
    contributor_note: str | None = None
    publisher: str | None = None
    description: str | None = None

    book_image: str | None = None
    amazon_product_url: str | None = None
    age_group: str | None = None
    book_review_link: str | None = None
    sunday_review_link: str | None = None
