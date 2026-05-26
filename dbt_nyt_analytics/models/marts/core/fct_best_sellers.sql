{{
    config(
        materialized='incremental',
        unique_key=['published_date', 'list_name_encoded', 'rank', 'list_updated'],
        partition_by={
            "field": "published_date",
            "data_type": "date",
            "granularity": "month"
        },
        cluster_by=['list_name_encoded', 'book_key']
    )
}}

with staged as (
    select * from {{ ref('stg_best_sellers') }}
    {% if is_incremental() %}
    where {{ get_incremental_filter('published_date') }}
    {% endif %}
),

with_book_key as (
    select
        -- Primary key
        s.published_date,
        s.list_name_encoded,
        s.rank,
        s.list_updated,

        -- Foreign key
        b.book_key,

        -- List metadata
        s.list_display_name,

        -- Rank metrics
        s.rank_last_week,
        s.weeks_on_list,

        -- Sales flags
        s.asterisk,
        s.dagger,

        -- Book natural key (degenerate)
        s.primary_isbn13,

        -- Content (degenerate)
        s.title,
        s.author,
        s.contributor,
        s.contributor_note,
        s.publisher,
        s.description,

        -- Age
        s.age_group,
        s.age_min,
        s.age_max,

        -- Links
        s.book_image,
        s.amazon_product_url,
        s.book_review_link,
        s.sunday_review_link

    from staged s
    left join {{ ref('dim_books') }} b
        on s.primary_isbn13 = b.primary_isbn13
)

select * from with_book_key
