with source as (
    select
        article_id,
        pub_date,
        pub_year,
        section_name,
        byline_person
    from {{ ref('stg_archive_articles') }}
    where has_authors = true
),

flattened as (
    select
        article_id,
        pub_date,
        pub_year,
        section_name,
        author.firstname as firstname,
        author.middlename as middlename,
        author.lastname as lastname,
        author.qualifier as qualifier,
        -- Construct full name
        trim(concat(
            coalesce(author.firstname, ''),
            ' ',
            coalesce(author.middlename, ''),
            ' ',
            coalesce(author.lastname, '')
        )) as author_full_name
    from source
    cross join unnest(byline_person) as author
    where author.lastname is not null
        or author.firstname is not null
)

select * from flattened
