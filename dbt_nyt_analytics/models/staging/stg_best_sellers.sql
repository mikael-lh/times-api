WITH source AS (
    SELECT * FROM {{ source('nyt_raw', 'best_sellers') }}
),

cleaned AS (
    SELECT
        -- Primary key
        published_date,
        list_name_encoded,
        rank,
        lower(trim(list_updated)) AS list_updated,

        -- List metadata
        trim(list_display_name) AS list_display_name,

        -- Rank metrics
        rank_last_week,
        weeks_on_list,

        -- Sales flags (nullable booleans)
        CASE
            WHEN asterisk IS NULL THEN NULL
            WHEN asterisk = 1 THEN TRUE
            ELSE FALSE
        END AS asterisk,
        CASE
            WHEN dagger IS NULL THEN NULL
            WHEN dagger = 1 THEN TRUE
            ELSE FALSE
        END AS dagger,

        -- Book identifiers and content
        trim(primary_isbn13) AS primary_isbn13,
        initcap(trim(title)) AS title,
        trim(author) AS author,
        trim(contributor) AS contributor,
        trim(contributor_note) AS contributor_note,
        trim(publisher) AS publisher,
        trim(description) AS description,

        -- Age group parsing (children's lists)
        trim(age_group) AS age_group,
        safe_cast(regexp_extract(age_group, r'(\d+)') AS int64) AS age_min,
        safe_cast(regexp_extract(age_group, r'\d+\s*(?:-|to)\s*(\d+)') AS int64) AS age_max,

        -- Links
        book_image,
        amazon_product_url,
        book_review_link,
        sunday_review_link

    FROM source
    WHERE
        published_date IS NOT NULL
        AND list_name_encoded IS NOT NULL
        AND rank IS NOT NULL
        AND list_updated IS NOT NULL
)

SELECT * FROM cleaned
