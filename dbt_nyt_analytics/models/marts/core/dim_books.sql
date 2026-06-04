WITH current_books AS (
    SELECT * FROM {{ ref('dim_books_history') }}
    WHERE valid_to IS NULL
),

with_key AS (
    SELECT
        {{ generate_surrogate_key(['primary_isbn13']) }} AS book_key,
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
        latest_published_date
    FROM current_books
)

SELECT * FROM with_key
