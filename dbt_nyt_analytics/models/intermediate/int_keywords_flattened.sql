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
        lower(trim(keyword.name)) AS keyword_name,
        lower(trim(keyword.value)) AS keyword_value,
        keyword.rank AS keyword_rank,
        keyword.major AS keyword_major
    FROM source
    CROSS JOIN unnest(keywords) AS keyword
)

SELECT * FROM flattened
