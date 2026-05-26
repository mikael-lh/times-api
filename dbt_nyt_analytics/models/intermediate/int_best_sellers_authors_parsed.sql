with source as (
    select * from {{ ref('stg_best_sellers') }}
),

parsed as (
    select
        * except (author),
        case
            when author is null or trim(author) = '' then null
            else array(
                select distinct initcap(trim(author_name))
                from unnest(
                    split(
                        regexp_replace(trim(author), r'(?i)\s+and\s+', '|||'),
                        '|||'
                    )
                ) as author_name
                where trim(author_name) != ''
            )
        end as authors
    from source
)

select * from parsed
