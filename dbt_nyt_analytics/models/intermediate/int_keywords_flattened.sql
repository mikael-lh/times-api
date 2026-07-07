WITH source AS (
    SELECT
        article_id,
        pub_date,
        pub_year,
        section_name,
        keywords
    FROM {{ ref('stg_archive_articles') }}
    WHERE has_keywords = TRUE
),

flattened AS (
    SELECT
        article_id,
        pub_date,
        pub_year,
        section_name,
        LOWER(TRIM(keyword.name)) AS keyword_name,
        LOWER(TRIM(keyword.value)) AS keyword_value,
        keyword.rank AS keyword_rank,
        keyword.major AS keyword_major
    FROM source
    CROSS JOIN UNNEST(keywords) AS keyword
),

deduped AS (
    SELECT
        article_id,
        pub_date,
        pub_year,
        section_name,
        keyword_name,
        keyword_value,
        MIN(keyword_rank) AS keyword_rank,
        MAX(keyword_major) AS keyword_major
    FROM flattened
    WHERE
        keyword_name IS NOT NULL
        AND keyword_value IS NOT NULL
        AND TRIM(keyword_value) != ''
    GROUP BY 1, 2, 3, 4, 5, 6
)

SELECT * FROM deduped
