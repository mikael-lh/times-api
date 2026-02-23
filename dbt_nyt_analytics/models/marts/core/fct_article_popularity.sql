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

with staged as (
    select * from {{ ref('stg_most_popular_articles') }}
    {% if is_incremental() %}
    where snapshot_date >= date_sub(
        (select max(snapshot_date) from {{ this }}),
        interval {{ var('incremental_lookback_days') }} day
    )
    {% endif %}
),

with_metrics as (
    select
        -- Keys
        snapshot_date,
        article_id,
        uri,
        asset_id,
        
        -- Dates
        published_date,
        updated_at,
        date_diff(snapshot_date, published_date, day) as days_since_published,
        
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
        
        -- Facets (for analysis)
        array_length(des_facet) as description_facet_count,
        array_length(org_facet) as organization_facet_count,
        array_length(per_facet) as person_facet_count,
        array_length(geo_facet) as geo_facet_count,
        
        -- Raw facets for downstream
        des_facet,
        org_facet,
        per_facet,
        geo_facet,
        
        -- Keywords
        adx_keywords
        
    from staged
)

select * from with_metrics
