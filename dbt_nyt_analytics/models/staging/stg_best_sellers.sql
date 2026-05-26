with source as (
    select * from {{ source('nyt_raw', 'best_sellers') }}
),

cleaned as (
    select
        -- Primary key
        published_date,
        list_name_encoded,
        rank,

        -- List metadata
        trim(list_display_name) as list_display_name,
        lower(trim(list_updated)) as list_updated,

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

        -- Parsed author / contributor arrays
        case
            when author is null or trim(author) = '' then null
            else array(
                select initcap(trim(author_name))
                from unnest(
                    split(
                        regexp_replace(trim(author), r'(?i)\s+and\s+', '|||'),
                        '|||'
                    )
                ) as author_name
                where trim(author_name) != ''
            )
        end as authors,
        case
            when contributor is null or trim(contributor) = '' then null
            else array(
                select initcap(trim(contributor_name))
                from unnest(
                    split(
                        regexp_replace(
                            regexp_replace(
                                regexp_replace(trim(contributor), r'(?i)^by\s+', ''),
                                r'(?i)\s+and\s+',
                                '|||'
                            ),
                            r',\s*',
                            '|||'
                        ),
                        '|||'
                    )
                ) as contributor_name
                where trim(contributor_name) != ''
            )
        end as contributors,

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
)

select * from cleaned
