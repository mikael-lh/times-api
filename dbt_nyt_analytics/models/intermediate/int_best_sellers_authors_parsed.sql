WITH source AS (
    SELECT * FROM {{ ref('stg_best_sellers') }}
),

parsed AS (
    SELECT
        * EXCEPT (author),
        CASE
            WHEN author IS NULL OR TRIM(author) = '' THEN NULL
            ELSE ARRAY(
                SELECT DISTINCT INITCAP(TRIM(author_name))
                FROM
                    UNNEST(
                        SPLIT(
                            REGEXP_REPLACE(TRIM(author), r'(?i)\s+and\s+', '|||'),
                            '|||'
                        )
                    ) AS author_name
                WHERE TRIM(author_name) != ''
            )
        END AS authors
    FROM source
)

SELECT * FROM parsed
