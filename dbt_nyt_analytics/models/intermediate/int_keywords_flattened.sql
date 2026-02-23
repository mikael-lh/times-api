with source as (
    select
        article_id,
        pub_date,
        pub_year,
        section_name,
        keywords
    from {{ ref('stg_archive_articles') }}
    where has_keywords = true
),

flattened as (
    select
        article_id,
        pub_date,
        pub_year,
        section_name,
        keyword.name as keyword_name,
        keyword.value as keyword_value,
        keyword.rank as keyword_rank,
        keyword.major as keyword_major
    from source
    cross join unnest(keywords) as keyword
)

select * from flattened
