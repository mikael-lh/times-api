with weekly as (
    select
        primary_isbn13,
        published_date,
        min(rank) as best_rank_that_week,
        array_agg(title order by list_name_encoded limit 1)[offset(0)] as title,
        array_agg(publisher order by list_name_encoded limit 1)[offset(0)] as publisher,
        array_agg(description order by list_name_encoded limit 1)[offset(0)] as description,
        array_agg(age_group order by list_name_encoded limit 1)[offset(0)] as age_group,
        array_agg(age_min order by list_name_encoded limit 1)[offset(0)] as age_min,
        array_agg(age_max order by list_name_encoded limit 1)[offset(0)] as age_max,
        array_agg(book_image order by list_name_encoded limit 1)[offset(0)] as book_image,
        array_agg(amazon_product_url order by list_name_encoded limit 1)[offset(0)] as amazon_product_url,
        array_agg(book_review_link order by list_name_encoded limit 1)[offset(0)] as book_review_link,
        array_agg(sunday_review_link order by list_name_encoded limit 1)[offset(0)] as sunday_review_link
    from {{ ref('stg_best_sellers') }}
    where primary_isbn13 is not null
        and trim(primary_isbn13) != ''
    group by 1, 2
),

running as (
    select
        *,
        min(best_rank_that_week) over (
            partition by primary_isbn13
            order by published_date
            rows between unbounded preceding and current row
        ) as top_rank
    from weekly
),

with_lags as (
    select
        *,
        lag(top_rank) over (
            partition by primary_isbn13
            order by published_date
        ) as prev_top_rank,
        lag(struct(
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
        )) over (
            partition by primary_isbn13
            order by published_date
        ) as prev_attrs
    from running
),

flagged as (
    select
        *,
        case
            when prev_top_rank is null then 1
            when top_rank != prev_top_rank then 1
            when struct(
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
            ) != prev_attrs then 1
            else 0
        end as is_new_version
    from with_lags
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

band_starts as (
    select *
    from banded
    qualify row_number() over (
        partition by primary_isbn13, scd_band
        order by published_date
    ) = 1
),

isbn_dates as (
    select
        primary_isbn13,
        max(published_date) as latest_published_date
    from weekly
    group by 1
),

with_valid_to as (
    select
        b.primary_isbn13,
        b.top_rank,
        b.published_date as valid_from,
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
        d.latest_published_date,
        lead(b.published_date) over (
            partition by b.primary_isbn13
            order by b.published_date
        ) as valid_to
    from band_starts b
    inner join isbn_dates d using (primary_isbn13)
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
from with_valid_to
