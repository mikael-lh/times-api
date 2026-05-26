with source as (
    select
        published_date,
        list_name_encoded,
        rank,
        list_updated,
        primary_isbn13,
        authors
    from {{ ref('int_best_sellers_authors_parsed') }}
    where authors is not null
        and array_length(authors) > 0
),

flattened as (
    select
        published_date,
        list_name_encoded,
        rank,
        list_updated,
        primary_isbn13,
        author_name as author_full_name
    from source
    cross join unnest(authors) as author_name
    where trim(author_name) != ''
)

select * from flattened
