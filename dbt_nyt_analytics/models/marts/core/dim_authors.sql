WITH article_authors AS (
    SELECT
        author_full_name,
        firstname,
        middlename,
        lastname,
        qualifier,
        1 AS source_priority
    FROM {{ ref('int_authors_flattened') }}
    WHERE
        author_full_name IS NOT NULL
        AND TRIM(author_full_name) != ''
),

book_authors AS (
    SELECT
        author_full_name,
        CAST(NULL AS STRING) AS firstname,
        CAST(NULL AS STRING) AS middlename,
        CAST(NULL AS STRING) AS lastname,
        CAST(NULL AS STRING) AS qualifier,
        2 AS source_priority
    FROM {{ ref('int_best_sellers_authors_flattened') }}
    WHERE
        author_full_name IS NOT NULL
        AND TRIM(author_full_name) != ''
),

combined AS (
    SELECT * FROM article_authors
    UNION ALL
    SELECT * FROM book_authors
),

deduped AS (
    SELECT
        author_full_name,
        firstname,
        middlename,
        lastname,
        qualifier
    FROM combined
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY author_full_name
        ORDER BY source_priority
    ) = 1
),

with_key AS (
    SELECT
        {{ generate_surrogate_key(['author_full_name']) }} AS author_key,
        author_full_name,
        firstname,
        middlename,
        lastname,
        qualifier
    FROM deduped
)

SELECT * FROM with_key
