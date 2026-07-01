{{
    config(
        materialized='incremental',
        unique_key=['snapshot_date', 'article_id'],
        partition_by={
            "field": "snapshot_date",
            "data_type": "date",
            "granularity": "day"
        }
    )
}}

WITH source_data AS (
    SELECT * FROM {{ source('nyt_raw', 'most_popular_articles') }}
    {% if is_incremental() %}
        WHERE {{ get_incremental_filter('snapshot_date') }}
    {% endif %}
),

cleaned AS (
    SELECT
        -- Primary keys
        snapshot_date,
        id AS article_id,
        uri,
        asset_id,

        -- Parse date strings to proper types
        safe.parse_date('%Y-%m-%d', published_date) AS published_date,
        safe.parse_timestamp('%Y-%m-%d %H:%M:%S', updated) AS updated_at,

        -- Categorization
        COALESCE(NULLIF(TRIM(source), ''), 'Unknown') AS source,
        COALESCE(NULLIF(TRIM(section), ''), 'Unknown') AS section,
        COALESCE(NULLIF(TRIM(subsection), ''), 'Unknown') AS subsection,
        COALESCE(NULLIF(TRIM(`type`), ''), 'Unknown') AS article_type,

        -- Content
        TRIM(title) AS title,
        TRIM(abstract) AS abstract,
        TRIM(byline) AS byline,
        url,

        -- Facets (arrays)
        des_facet,
        org_facet,
        per_facet,
        geo_facet,

        -- JSON and keywords
        media_count_by_type,
        adx_keywords

    FROM source_data
    WHERE id IS NOT NULL
)

SELECT * FROM cleaned
