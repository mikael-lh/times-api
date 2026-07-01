{{
    config(
        materialized='incremental',
        unique_key='article_id',
        partition_by={
            "field": "pub_date",
            "data_type": "date",
            "granularity": "month"
        },
        cluster_by=['section_name', 'news_desk']
    )
}}

WITH source AS (
    SELECT * FROM {{ source('nyt_raw', 'archive_articles') }}
    {% if is_incremental() %}
        WHERE {{ get_incremental_filter('pub_date') }}
    {% endif %}
),

cleaned AS (
    SELECT
        -- Primary key
        article_id,
        uri,

        -- Dates
        pub_date,
        EXTRACT(YEAR FROM pub_date) AS pub_year,
        EXTRACT(MONTH FROM pub_date) AS pub_month,

        -- Categorization
        COALESCE(NULLIF(TRIM(section_name), ''), 'Unknown') AS section_name,
        COALESCE(NULLIF(TRIM(news_desk), ''), 'Unknown') AS news_desk,
        COALESCE(NULLIF(TRIM(type_of_material), ''), 'Unknown') AS type_of_material,
        COALESCE(NULLIF(TRIM(document_type), ''), 'Unknown') AS document_type,

        -- Content metrics
        COALESCE(word_count, 0) AS word_count,

        -- URLs
        web_url,

        -- Text fields
        TRIM(headline_main) AS headline_main,
        TRIM(byline_original) AS byline_original,
        TRIM(abstract) AS abstract,
        TRIM(snippet) AS snippet,

        -- Nested arrays (kept as-is for intermediate layer to flatten)
        keywords,
        byline_person,

        -- JSON fields
        multimedia_count_by_type,

        -- Derived: has content flags
        COALESCE(ARRAY_LENGTH(keywords) > 0, FALSE) AS has_keywords,
        COALESCE(ARRAY_LENGTH(byline_person) > 0, FALSE) AS has_authors,
        COALESCE(multimedia_count_by_type IS NOT NULL, FALSE) AS has_multimedia

    FROM source
    WHERE article_id IS NOT NULL
)

SELECT * FROM cleaned
