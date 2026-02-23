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

with staged_articles as (
    select * from {{ ref('stg_archive_articles') }}
    {% if is_incremental() %}
    where pub_date >= date_sub(
        (select max(pub_date) from {{ this }}),
        interval {{ var('incremental_lookback_days') }} day
    )
    {% endif %}
),

author_counts as (
    select
        article_id,
        count(*) as author_count
    from {{ ref('int_authors_flattened') }}
    group by 1
),

keyword_counts as (
    select
        article_id,
        count(*) as keyword_count,
        countif(keyword_major = 'Y') as major_keyword_count
    from {{ ref('int_keywords_flattened') }}
    group by 1
),

final as (
    select
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
        coalesce(ac.author_count, 0) as author_count,
        coalesce(kc.keyword_count, 0) as keyword_count,
        coalesce(kc.major_keyword_count, 0) as major_keyword_count,
        
        -- Content
        a.headline_main,
        a.byline_original,
        a.abstract,
        a.web_url,
        
        -- Flags
        a.has_keywords,
        a.has_authors,
        a.has_multimedia
        
    from staged_articles a
    left join author_counts ac on a.article_id = ac.article_id
    left join keyword_counts kc on a.article_id = kc.article_id
)

select * from final
