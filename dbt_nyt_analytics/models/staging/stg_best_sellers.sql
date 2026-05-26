with source as (
    select * from {{ source('nyt_raw', 'best_sellers') }}
),

cleaned as (
    select
        -- Primary key
        published_date,
        list_name_encoded,
        rank,
        lower(trim(list_updated)) as list_updated,

        -- List metadata
        trim(list_display_name) as list_display_name,

        -- Rank metrics
        rank_last_week,
        weeks_on_list,

        -- Sales flags (nullable booleans)
        case
            when asterisk is null then null
            when asterisk = 1 then true
            else false
        end as asterisk,
        case
            when dagger is null then null
            when dagger = 1 then true
            else false
        end as dagger,

        -- Book identifiers and content
        trim(primary_isbn13) as primary_isbn13,
        initcap(trim(title)) as title,
        trim(author) as author,
        trim(contributor) as contributor,
        trim(contributor_note) as contributor_note,
        trim(publisher) as publisher,
        trim(description) as description,

        -- Age group parsing (children's lists)
        trim(age_group) as age_group,
        safe_cast(regexp_extract(age_group, r'(\d+)') as int64) as age_min,
        safe_cast(regexp_extract(age_group, r'\d+\s*(?:-|to)\s*(\d+)') as int64) as age_max,

        -- Links
        book_image,
        amazon_product_url,
        book_review_link,
        sunday_review_link

    from source
    where published_date is not null
        and list_name_encoded is not null
        and rank is not null
        and list_updated is not null
)

select * from cleaned
