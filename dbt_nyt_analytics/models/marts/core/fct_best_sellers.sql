{{
    config(
        materialized='incremental',
        unique_key=['published_date', 'list_name_encoded', 'rank', 'list_updated'],
        on_schema_change='append_new_columns',
        partition_by={
            "field": "published_date",
            "data_type": "date",
            "granularity": "month"
        },
        cluster_by=['list_name_encoded', 'book_key', 'book_scd_key', 'author_key']
    )
}}

with staged as (
    select * from {{ ref('stg_best_sellers') }}
    {% if is_incremental() %}
    where {{ get_incremental_filter('published_date') }}
    {% endif %}
),

with_book_keys as (
    select
        s.published_date,
        s.list_name_encoded,
        s.rank,
        s.list_updated,
        b.book_key,
        bh.book_scd_key,
        initcap(trim(s.author)) as author_full_name,
        s.list_display_name,
        s.rank_last_week,
        s.weeks_on_list,
        s.asterisk,
        s.dagger
    from staged s
    left join {{ ref('dim_books') }} b
        on s.primary_isbn13 = b.primary_isbn13
    left join {{ ref('dim_books_history') }} bh
        on s.primary_isbn13 = bh.primary_isbn13
        and timestamp(s.published_date) >= bh.dbt_valid_from
        and (bh.dbt_valid_to is null or timestamp(s.published_date) < bh.dbt_valid_to)
),

final as (
    select
        b.published_date,
        b.list_name_encoded,
        b.rank,
        b.list_updated,
        b.book_key,
        b.book_scd_key,
        a.author_key,
        b.list_display_name,
        b.rank_last_week,
        b.weeks_on_list,
        b.asterisk,
        b.dagger
    from with_book_keys b
    left join {{ ref('dim_authors') }} a
        on b.author_full_name = a.author_full_name
)

select * from final
