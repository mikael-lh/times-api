WITH flattened AS (
    SELECT
        article_id,
        keyword_name,
        keyword_value,
        keyword_rank,
        keyword_major
    FROM {{ ref('int_keywords_flattened') }}
),

with_key AS (
    SELECT
        f.article_id,
        k.keyword_key,
        k.keyword_name,
        k.keyword_value,
        f.keyword_rank,
        f.keyword_major
    FROM flattened AS f
    INNER JOIN {{ ref('dim_keywords') }} AS k
        ON
            f.keyword_name = k.keyword_name
            AND f.keyword_value = k.keyword_value
)

SELECT * FROM with_key
