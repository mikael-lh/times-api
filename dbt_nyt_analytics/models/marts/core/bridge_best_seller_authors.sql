with flattened as (
    select
        published_date,
        list_name_encoded,
        rank,
        list_updated,
        author_full_name
    from {{ ref('int_best_sellers_authors_flattened') }}
),

with_key as (
    select
        f.published_date,
        f.list_name_encoded,
        f.rank,
        f.list_updated,
        a.author_key,
        f.author_full_name
    from flattened f
    inner join {{ ref('dim_authors') }} a
        on f.author_full_name = a.author_full_name
)

select * from with_key
