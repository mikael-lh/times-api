with authors as (
    select distinct
        firstname,
        middlename,
        lastname,
        qualifier,
        author_full_name
    from {{ ref('int_authors_flattened') }}
    where author_full_name is not null
        and trim(author_full_name) != ''
),

with_key as (
    select
        {{ dbt_utils.generate_surrogate_key(['firstname', 'middlename', 'lastname']) }} as author_key,
        firstname,
        middlename,
        lastname,
        qualifier,
        author_full_name
    from authors
)

select * from with_key
