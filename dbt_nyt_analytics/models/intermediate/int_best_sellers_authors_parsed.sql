WITH source AS (
    SELECT * FROM {{ ref('stg_best_sellers') }}
),

parsed AS (
    SELECT
        * EXCEPT (author),
        CASE
            WHEN author IS NULL OR trim(author) = '' THEN NULL
            ELSE array(
                SELECT DISTINCT initcap(trim(author_name))
                FROM
                    unnest(
                        split(
                            regexp_replace(trim(author), r'(?i)\s+and\s+', '|||'),
                            '|||'
                        )
                    ) AS author_name
                WHERE trim(author_name) != ''
            )
        END AS authors
    FROM source
)

SELECT * FROM parsed
