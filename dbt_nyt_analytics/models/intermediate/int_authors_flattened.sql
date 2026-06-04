WITH source AS (
    SELECT
        article_id,
        pub_date,
        pub_year,
        section_name,
        byline_person
    FROM {{ ref('stg_archive_articles') }}
    WHERE has_authors = TRUE
),

flattened AS (
    SELECT
        article_id,
        pub_date,
        pub_year,
        section_name,
        author.firstname,
        author.middlename,
        author.lastname,
        author.qualifier,
        -- Construct full name
        trim(concat(
            coalesce(author.firstname, ''),
            ' ',
            coalesce(author.middlename, ''),
            ' ',
            coalesce(author.lastname, '')
        )) AS author_full_name
    FROM source
    CROSS JOIN unnest(byline_person) AS author
    WHERE
        author.lastname IS NOT NULL
        OR author.firstname IS NOT NULL
)

SELECT * FROM flattened
