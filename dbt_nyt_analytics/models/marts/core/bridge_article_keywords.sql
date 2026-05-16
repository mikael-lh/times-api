with flattened as (
    select
        article_id,
        keyword_name,
        keyword_value,
        keyword_rank,
        keyword_major
    from {{ ref('int_keywords_flattened') }}
),

with_key as (
    select
        f.article_id,
        k.keyword_key,
        f.keyword_rank,
        f.keyword_major
    from flattened f
    inner join {{ ref('dim_keywords') }} k
        on f.keyword_name = k.keyword_name
        and f.keyword_value = k.keyword_value
)

select * from with_key
