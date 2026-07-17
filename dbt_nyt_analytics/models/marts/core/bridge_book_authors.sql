WITH flattened AS (
    SELECT DISTINCT
        primary_isbn13,
        author_full_name
    FROM {{ ref('int_best_sellers_authors_flattened') }}
    WHERE
        primary_isbn13 IS NOT NULL
        AND TRIM(primary_isbn13) != ''
),

with_keys AS (
    SELECT
        b.book_key,
        a.author_key,
        f.author_full_name
    FROM flattened AS f
    INNER JOIN {{ ref('dim_books') }} AS b
        ON f.primary_isbn13 = b.primary_isbn13
    INNER JOIN {{ ref('dim_authors') }} AS a
        ON f.author_full_name = a.author_full_name
)

SELECT * FROM with_keys
