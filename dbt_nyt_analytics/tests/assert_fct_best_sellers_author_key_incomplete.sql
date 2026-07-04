-- Multi-author Best Sellers list entries should not expose a single author_key on the fact.
-- The bridge table is the correct many-to-many representation.
-- This test fails for any list entry with 2+ bridge authors where fct_best_sellers.author_key is populated.

with bridge as (
    select
        published_date,
        list_name_encoded,
        rank,
        list_updated,
        count(*) as bridge_author_count,
        string_agg(distinct author_full_name, ' | ' order by author_full_name) as bridge_authors,
        string_agg(distinct cast(author_key as string), ',' order by cast(author_key as string)) as bridge_author_keys
    from {{ ref('bridge_best_seller_authors') }}
    group by 1, 2, 3, 4
    having count(*) > 1
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

joined as (
    select
        b.published_date,
        b.list_name_encoded,
        b.rank,
        b.list_updated,
        b.bridge_author_count,
        b.bridge_authors,
        f.fct_author_key,
        case
            when f.fct_author_key is null then 'multi_author_but_fct_key_null'
            when cast(f.fct_author_key as string) not in unnest(split(b.bridge_author_keys, ','))
                then 'fct_key_not_in_bridge'
            else 'multi_author_with_single_fct_key'
        end as issue_type
    from bridge b
    inner join fct f using (published_date, list_name_encoded, rank, list_updated)
)

select *
from joined
where issue_type in ('multi_author_with_single_fct_key', 'fct_key_not_in_bridge')
