{{ config(severity='warn') }}

-- Diagnostic overview for multi-author Best Sellers rows (warn-only; does not fail CI).
with bridge as (
    select
        published_date,
        list_name_encoded,
        rank,
        list_updated,
        count(*) as bridge_author_count,
        string_agg(distinct cast(author_key as string), ',' order by cast(author_key as string)) as bridge_author_keys
    from {{ ref('bridge_best_seller_authors') }}
    group by 1, 2, 3, 4
),

fct as (
    select
        published_date,
        list_name_encoded,
        rank,
        list_updated,
        author_key as fct_author_key
    from {{ ref('fct_best_sellers') }}
),

classified as (
    select
        coalesce(b.bridge_author_count, 0) as bridge_author_count,
        case
            when coalesce(b.bridge_author_count, 0) <= 1 then 'single_or_no_bridge'
            when f.fct_author_key is null then 'multi_author_fct_key_null'
            when cast(f.fct_author_key as string) not in unnest(split(b.bridge_author_keys, ','))
                then 'multi_author_fct_key_not_in_bridge'
            else 'multi_author_fct_key_is_one_of_many'
        end as bucket
    from fct f
    left join bridge b using (published_date, list_name_encoded, rank, list_updated)
)

select bucket, count(*) as entry_count
from classified
group by 1
