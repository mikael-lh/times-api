{% snapshot books_snapshot %}

{{
    config(
        target_schema='dbt_snapshots',
        unique_key='primary_isbn13',
        strategy='check',
        check_cols=[
            'title',
            'publisher',
            'description',
            'top_rank',
            'age_group',
            'age_min',
            'age_max',
            'book_image',
            'amazon_product_url',
            'book_review_link',
            'sunday_review_link',
        ],
    )
}}

select * from {{ ref('int_best_sellers_books_snapshot_source') }}

{% endsnapshot %}
