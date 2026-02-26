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

with source as (
    select * from {{ source('nyt_raw', 'archive_articles') }}
    {% if is_incremental() %}
    where {{ get_incremental_filter('pub_date') }}
    {% endif %}
),

cleaned as (
    select
        -- Primary key
        article_id,
        uri,
        
        -- Dates
        pub_date,
        extract(year from pub_date) as pub_year,
        extract(month from pub_date) as pub_month,
        
        -- Categorization
        coalesce(nullif(trim(section_name), ''), 'Unknown') as section_name,
        coalesce(nullif(trim(news_desk), ''), 'Unknown') as news_desk,
        coalesce(nullif(trim(type_of_material), ''), 'Unknown') as type_of_material,
        coalesce(nullif(trim(document_type), ''), 'Unknown') as document_type,
        
        -- Content metrics
        coalesce(word_count, 0) as word_count,
        
        -- URLs
        web_url,
        
        -- Text fields
        trim(headline_main) as headline_main,
        trim(byline_original) as byline_original,
        trim(abstract) as abstract,
        trim(snippet) as snippet,
        
        -- Nested arrays (kept as-is for intermediate layer to flatten)
        keywords,
        byline_person,
        
        -- JSON fields
        multimedia_count_by_type,
        
        -- Derived: has content flags
        case when array_length(keywords) > 0 then true else false end as has_keywords,
        case when array_length(byline_person) > 0 then true else false end as has_authors,
        case 
            when multimedia_count_by_type is not null 
            then true 
            else false 
        end as has_multimedia
        
    from source
    where article_id is not null
)

select * from cleaned
