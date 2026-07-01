WITH source AS (
    SELECT
        published_date,
        list_name_encoded,
        rank,
        list_updated,
        primary_isbn13,
        authors
    FROM {{ ref('int_best_sellers_authors_parsed') }}
    WHERE
        authors IS NOT NULL
        AND ARRAY_LENGTH(authors) > 0
),

flattened AS (
    SELECT
        published_date,
        list_name_encoded,
        rank,
        list_updated,
        primary_isbn13,
        author_name AS author_full_name
    FROM source
    CROSS JOIN UNNEST(authors) AS author_name
    WHERE TRIM(author_name) != ''
)

SELECT * FROM flattened
