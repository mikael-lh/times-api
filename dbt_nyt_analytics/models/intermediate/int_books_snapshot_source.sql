{{ config(materialized='view') }}

WITH rank_metrics AS (
    SELECT
        primary_isbn13,
        MIN(rank) AS top_rank
    FROM {{ ref('stg_best_sellers') }}
    WHERE
        primary_isbn13 IS NOT NULL
        AND TRIM(primary_isbn13) != ''
    GROUP BY 1
),

book_attrs AS (
    SELECT * FROM {{ ref('int_best_sellers_books') }}
),

joined AS (
    SELECT
        b.primary_isbn13,
        b.title,
        b.publisher,
        b.description,
        b.age_group,
        b.age_min,
        b.age_max,
        b.book_image,
        b.amazon_product_url,
        b.book_review_link,
        b.sunday_review_link,
        b.latest_published_date,
        r.top_rank
    FROM book_attrs AS b
    INNER JOIN rank_metrics AS r USING (primary_isbn13)
)

SELECT * FROM joined
