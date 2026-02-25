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

with source as (
    select * from {{ source('nyt_raw', 'most_popular_articles') }}
    {% if is_incremental() %}
    where {{ get_incremental_filter('snapshot_date') }}
    {% endif %}
),

cleaned as (
    select
        -- Primary keys
        snapshot_date,
        id as article_id,
        uri,
        asset_id,
        
        -- Parse date strings to proper types
        safe.parse_date('%Y-%m-%d', published_date) as published_date,
        safe.parse_timestamp('%Y-%m-%d %H:%M:%S', updated) as updated_at,
        
        -- Categorization
        coalesce(nullif(trim(source), ''), 'Unknown') as source,
        coalesce(nullif(trim(section), ''), 'Unknown') as section,
        coalesce(nullif(trim(subsection), ''), 'Unknown') as subsection,
        coalesce(nullif(trim(type), ''), 'Unknown') as article_type,
        
        -- Content
        trim(title) as title,
        trim(abstract) as abstract,
        trim(byline) as byline,
        url,
        
        -- Facets (arrays)
        des_facet,
        org_facet,
        per_facet,
        geo_facet,
        
        -- JSON and keywords
        media_count_by_type,
        adx_keywords
        
    from source
    where id is not null
)

select * from cleaned
