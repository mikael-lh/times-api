{{
    config(
        materialized='incremental',
        unique_key='article_id',
        partition_by={
            "field": "pub_date",
            "data_type": "date",
            "granularity": "month"
        },
        cluster_by=['section_name', 'pub_year']
    )
}}

WITH staged_articles AS (
    SELECT * FROM {{ ref('stg_archive_articles') }}
    {% if is_incremental() %}
        WHERE {{ get_incremental_filter('pub_date') }}
    {% endif %}
),

author_counts AS (
    SELECT
        article_id,
        count(*) AS author_count
    FROM {{ ref('int_authors_flattened') }}
    GROUP BY 1
),

keyword_counts AS (
    SELECT
        article_id,
        count(*) AS keyword_count,
        countif(keyword_major = 'Y') AS major_keyword_count
    FROM {{ ref('int_keywords_flattened') }}
    GROUP BY 1
),

final AS (
    SELECT
        -- Keys
        a.article_id,
        a.uri,

        -- Date dimensions
        a.pub_date,
        a.pub_year,
        a.pub_month,

        -- Categorization
        a.section_name,
        a.news_desk,
        a.type_of_material,
        a.document_type,

        -- Metrics
        a.word_count,
        coalesce(ac.author_count, 0) AS author_count,
        coalesce(kc.keyword_count, 0) AS keyword_count,
        coalesce(kc.major_keyword_count, 0) AS major_keyword_count,

        -- Content
        a.headline_main,
        a.byline_original,
        a.abstract,
        a.web_url,

        -- Flags
        a.has_keywords,
        a.has_authors,
        a.has_multimedia

    FROM staged_articles AS a
    LEFT JOIN author_counts AS ac ON a.article_id = ac.article_id
    LEFT JOIN keyword_counts AS kc ON a.article_id = kc.article_id
)

SELECT * FROM final
