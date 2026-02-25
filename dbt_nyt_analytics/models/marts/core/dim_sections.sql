with sections as (
    select distinct
        section_name,
        news_desk
    from {{ ref('stg_archive_articles') }}
),

with_key as (
    select
        {{ dbt_utils.generate_surrogate_key(['section_name', 'news_desk']) }} as section_key,
        section_name,
        news_desk
    from sections
)

select * from with_key
