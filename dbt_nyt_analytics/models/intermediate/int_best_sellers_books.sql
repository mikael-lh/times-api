WITH source AS (
    SELECT
        published_date,
        list_name_encoded,
        primary_isbn13,
        title,
        publisher,
        description,
        age_group,
        age_min,
        age_max,
        book_image,
        amazon_product_url,
        book_review_link,
        sunday_review_link
    FROM {{ ref('stg_best_sellers') }}
    WHERE
        primary_isbn13 IS NOT NULL
        AND TRIM(primary_isbn13) != ''
),

ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY primary_isbn13
            ORDER BY published_date DESC, list_name_encoded ASC
        ) AS recency_rank
    FROM source
),

deduped AS (
    SELECT
        primary_isbn13,
        title,
        publisher,
        description,
        age_group,
        age_min,
        age_max,
        book_image,
        amazon_product_url,
        book_review_link,
        sunday_review_link,
        published_date AS latest_published_date
    FROM ranked
    WHERE recency_rank = 1
)

SELECT * FROM deduped
