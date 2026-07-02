{{
    config(
        materialized='incremental',
        unique_key=['snapshot_date', 'article_id'],
        partition_by={
            "field": "snapshot_date",
            "data_type": "date",
            "granularity": "day"
        },
        on_schema_change='sync_all_columns'
    )
}}

WITH staged AS (
    SELECT * FROM {{ ref('stg_most_popular_articles') }}
    {% if is_incremental() %}
        WHERE {{ get_incremental_filter('snapshot_date') }}
    {% endif %}
),

with_metrics AS (
    SELECT
        -- Keys
        snapshot_date,
        article_id,
        uri,
        asset_id,

        -- Dates
        published_date,
        updated_at,
        DATE_DIFF(snapshot_date, published_date, DAY) AS days_since_published,

        -- Categorization
        source,
        section,
        subsection,
        article_type,

        -- Content
        title,
        abstract,
        byline,
        url,

        -- Facet counts (for analysis)
        ARRAY_LENGTH(des_facet) AS description_facet_count,
        ARRAY_LENGTH(org_facet) AS organization_facet_count,
        ARRAY_LENGTH(per_facet) AS person_facet_count,
        ARRAY_LENGTH(geo_facet) AS geo_facet_count,

        -- Keywords
        adx_keywords

    FROM staged
)

SELECT * FROM with_metrics
