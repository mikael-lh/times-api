WITH keywords AS (
    SELECT DISTINCT
        keyword_name,
        keyword_value
    FROM {{ ref('int_keywords_flattened') }}
    WHERE
        keyword_value IS NOT NULL
        AND trim(keyword_value) != ''
),

with_key AS (
    SELECT
        {{ generate_surrogate_key(['keyword_name', 'keyword_value']) }} AS keyword_key,
        keyword_name,
        keyword_value
    FROM keywords
)

SELECT * FROM with_key
