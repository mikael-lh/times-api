SELECT
    book_scd_key,
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
    valid_from,
    valid_to
FROM {{ ref('int_books_top_rank_scd') }}
