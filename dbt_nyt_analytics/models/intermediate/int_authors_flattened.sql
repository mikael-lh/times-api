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
        TRIM(CONCAT(
            COALESCE(author.firstname, ''),
            ' ',
            COALESCE(author.middlename, ''),
            ' ',
            COALESCE(author.lastname, '')
        )) AS author_full_name
    FROM source
    CROSS JOIN UNNEST(byline_person) AS author
),

deduped AS (
    SELECT DISTINCT
        article_id,
        pub_date,
        pub_year,
        section_name,
        firstname,
        middlename,
        lastname,
        qualifier,
        author_full_name
    FROM flattened
)

SELECT * FROM deduped
