{{
    config(
        materialized='incremental',
        unique_key=['published_date', 'list_name_encoded', 'rank', 'list_updated'],
        partition_by={
            "field": "published_date",
            "data_type": "date",
            "granularity": "month"
        },
        cluster_by=['list_name_encoded', 'book_key', 'author_key']
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
        s.published_date,
        s.list_name_encoded,
        s.rank,
        s.list_updated,
        b.book_key,
        s.list_display_name,
        s.rank_last_week,
        s.weeks_on_list,
        s.asterisk,
        s.dagger
    from staged s
    left join {{ ref('dim_books') }} b
        on s.primary_isbn13 = b.primary_isbn13
),

primary_author as (
    select
        f.published_date,
        f.list_name_encoded,
        f.rank,
        f.list_updated,
        a.author_key
    from {{ ref('int_best_sellers_authors_flattened') }} f
    inner join {{ ref('dim_authors') }} a
        on f.author_full_name = a.author_full_name
    qualify row_number() over (
        partition by f.published_date, f.list_name_encoded, f.rank, f.list_updated
        order by f.author_full_name
    ) = 1
),

final as (
    select
        b.published_date,
        b.list_name_encoded,
        b.rank,
        b.list_updated,
        b.book_key,
        p.author_key,
        b.list_display_name,
        b.rank_last_week,
        b.weeks_on_list,
        b.asterisk,
        b.dagger
    from with_book_key b
    left join primary_author p
        using (published_date, list_name_encoded, rank, list_updated)
)

select * from final
