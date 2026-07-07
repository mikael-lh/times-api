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
        TRIM(CONCAT(
            COALESCE(author.firstname, ''),
            ' ',
            COALESCE(author.middlename, ''),
            ' ',
            COALESCE(author.lastname, '')
        )) AS author_full_name
    FROM source
    CROSS JOIN UNNEST(byline_person) AS author
    WHERE
        NULLIF(TRIM(COALESCE(author.firstname, '')), '') IS NOT NULL
        OR NULLIF(TRIM(COALESCE(author.lastname, '')), '') IS NOT NULL
),

deduped AS (
    SELECT
        article_id,
        pub_date,
        pub_year,
        section_name,
        author_full_name,
        ANY_VALUE(firstname) AS firstname,
        ANY_VALUE(middlename) AS middlename,
        ANY_VALUE(lastname) AS lastname,
        ANY_VALUE(qualifier) AS qualifier
    FROM flattened
    WHERE
        TRIM(author_full_name) != ''
        AND LOWER(TRIM(author_full_name)) != 'none'
    GROUP BY 1, 2, 3, 4, 5
)

SELECT * FROM deduped
