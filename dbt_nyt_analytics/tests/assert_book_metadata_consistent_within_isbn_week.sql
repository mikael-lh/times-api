-- Fail when the same book has conflicting metadata across lists in the same week.
-- int_books_top_rank_scd picks metadata from the alphabetically first list_name_encoded.

with weekly_conflicts as (
    select
        primary_isbn13,
        published_date
    from {{ ref('stg_best_sellers') }}
    where primary_isbn13 is not null
        and trim(primary_isbn13) != ''
    group by 1, 2
    having count(distinct title) > 1
        or count(distinct publisher) > 1
        or count(distinct description) > 1
        or count(distinct age_group) > 1
        or count(distinct age_min) > 1
        or count(distinct age_max) > 1
        or count(distinct book_image) > 1
        or count(distinct amazon_product_url) > 1
        or count(distinct book_review_link) > 1
        or count(distinct sunday_review_link) > 1
)

select * from weekly_conflicts
