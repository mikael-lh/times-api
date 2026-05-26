{% snapshot books_snapshot %}

with rank_metrics as (
    select
        primary_isbn13,
        min(rank) as top_rank
    from {{ ref('stg_best_sellers') }}
    where primary_isbn13 is not null
        and trim(primary_isbn13) != ''
    group by 1
),

book_attrs as (
    select * from {{ ref('int_best_sellers_books') }}
),

joined as (
    select
        b.primary_isbn13,
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
        b.latest_published_date,
        r.top_rank
    from book_attrs b
    inner join rank_metrics r using (primary_isbn13)
)

select * from joined

{% endsnapshot %}
