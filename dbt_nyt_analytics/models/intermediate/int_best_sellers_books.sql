with source as (
    select
        published_date,
        primary_isbn13,
        title,
        publisher,
        description,
        age_group,
        age_min,
        age_max,
        book_image,
        amazon_product_url,
        book_review_link,
        sunday_review_link
    from {{ ref('stg_best_sellers') }}
    where primary_isbn13 is not null
        and trim(primary_isbn13) != ''
),

ranked as (
    select
        *,
        row_number() over (
            partition by primary_isbn13
            order by published_date desc
        ) as recency_rank
    from source
),

deduped as (
    select
        primary_isbn13,
        title,
        publisher,
        description,
        age_group,
        age_min,
        age_max,
        book_image,
        amazon_product_url,
        book_review_link,
        sunday_review_link,
        published_date as latest_published_date
    from ranked
    where recency_rank = 1
)

select * from deduped
