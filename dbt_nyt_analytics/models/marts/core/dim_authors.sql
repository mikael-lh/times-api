with article_authors as (
    select
        author_full_name,
        firstname,
        middlename,
        lastname,
        qualifier,
        1 as source_priority
    from {{ ref('int_authors_flattened') }}
    where author_full_name is not null
        and trim(author_full_name) != ''
),

book_authors as (
    select
        author_full_name,
        cast(null as string) as firstname,
        cast(null as string) as middlename,
        cast(null as string) as lastname,
        cast(null as string) as qualifier,
        2 as source_priority
    from {{ ref('int_best_sellers_authors_flattened') }}
    where author_full_name is not null
        and trim(author_full_name) != ''
),

combined as (
    select * from article_authors
    union all
    select * from book_authors
),

deduped as (
    select
        author_full_name,
        firstname,
        middlename,
        lastname,
        qualifier
    from combined
    qualify row_number() over (
        partition by author_full_name
        order by source_priority
    ) = 1
),

with_key as (
    select
        {{ dbt_utils.generate_surrogate_key(['author_full_name']) }} as author_key,
        author_full_name,
        firstname,
        middlename,
        lastname,
        qualifier
    from deduped
)

select * from with_key
