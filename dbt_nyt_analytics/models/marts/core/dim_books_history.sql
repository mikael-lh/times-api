select
    dbt_scd_id as book_scd_key,
    primary_isbn13,
    title,
    publisher,
    description,
    age_group,
    age_min,
    age_max,
    top_rank,
    book_image,
    amazon_product_url,
    book_review_link,
    sunday_review_link,
    latest_published_date,
    dbt_valid_from,
    dbt_valid_to,
    dbt_updated_at
from {{ ref('books_snapshot') }}
