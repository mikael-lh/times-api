with weekly as (
    select
        primary_isbn13,
        published_date,
        min(rank) as best_rank_that_week
    from {{ ref('stg_best_sellers') }}
    where primary_isbn13 is not null
        and trim(primary_isbn13) != ''
    group by 1, 2
),

running as (
    select
        primary_isbn13,
        published_date,
        min(best_rank_that_week) over (
            partition by primary_isbn13
            order by published_date
            rows between unbounded preceding and current row
        ) as top_rank
    from weekly
),

rank_changes as (
    select
        *,
        lag(top_rank) over (
            partition by primary_isbn13
            order by published_date
        ) as prev_top_rank
    from running
),

flagged as (
    select
        *,
        case
            when prev_top_rank is null then 1
            when top_rank != prev_top_rank then 1
            else 0
        end as is_new_version
    from rank_changes
),

banded as (
    select
        *,
        sum(is_new_version) over (
            partition by primary_isbn13
            order by published_date
        ) as scd_band
    from flagged
),

versions as (
    select
        primary_isbn13,
        scd_band,
        any_value(top_rank) as top_rank,
        min(published_date) as valid_from
    from banded
    group by 1, 2
),

with_valid_to as (
    select
        primary_isbn13,
        top_rank,
        valid_from,
        lead(valid_from) over (
            partition by primary_isbn13
            order by valid_from
        ) as valid_to
    from versions
),

with_metadata as (
    select
        v.primary_isbn13,
        v.top_rank,
        v.valid_from,
        v.valid_to,
        b.title,
        b.publisher,
        b.description,
        b.age_group,
        b.age_min,
        b.age_max,
        b.book_image,
        b.amazon_product_url,
        b.book_review_link,
        b.sunday_review_link,
        b.latest_published_date
    from with_valid_to v
    inner join {{ ref('int_best_sellers_books') }} b using (primary_isbn13)
)

select
    {{ dbt_utils.generate_surrogate_key(['primary_isbn13', 'valid_from']) }} as book_scd_key,
    primary_isbn13,
    title,
    publisher,
    description,
    age_group,
    age_min,
    age_max,
    top_rank,
    book_image,
    amazon_product_url,
    book_review_link,
    sunday_review_link,
    latest_published_date,
    valid_from,
    valid_to
from with_metadata
