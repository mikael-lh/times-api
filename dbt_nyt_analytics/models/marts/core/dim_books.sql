with current_books as (
    select * from {{ ref('dim_books_history') }}
    where valid_to is null
),

with_key as (
    select
        {{ dbt_utils.generate_surrogate_key(['primary_isbn13']) }} as book_key,
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
        latest_published_date
    from current_books
)

select * from with_key
