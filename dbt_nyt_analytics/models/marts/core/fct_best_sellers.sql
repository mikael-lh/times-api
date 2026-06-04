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

WITH staged AS (
    SELECT * FROM {{ ref('stg_best_sellers') }}
    {% if is_incremental() %}
        WHERE {{ get_incremental_filter('published_date') }}
    {% endif %}
),

with_book_keys AS (
    SELECT
        s.published_date,
        s.list_name_encoded,
        s.rank,
        s.list_updated,
        b.book_key,
        bh.book_scd_key,
        initcap(trim(s.author)) AS author_full_name,
        s.list_display_name,
        s.rank_last_week,
        s.weeks_on_list,
        s.asterisk,
        s.dagger
    FROM staged AS s
    LEFT JOIN {{ ref('dim_books') }} AS b
        ON s.primary_isbn13 = b.primary_isbn13
    LEFT JOIN {{ ref('dim_books_history') }} AS bh
        ON
            s.primary_isbn13 = bh.primary_isbn13
            AND s.published_date >= bh.valid_from
            AND (bh.valid_to IS NULL OR s.published_date < bh.valid_to)
),

final AS (
    SELECT
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
    FROM with_book_keys AS b
    LEFT JOIN {{ ref('dim_authors') }} AS a
        ON b.author_full_name = a.author_full_name
)

SELECT * FROM final
