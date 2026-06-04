WITH flattened AS (
    SELECT
        published_date,
        list_name_encoded,
        rank,
        list_updated,
        author_full_name
    FROM {{ ref('int_best_sellers_authors_flattened') }}
),

with_key AS (
    SELECT
        f.published_date,
        f.list_name_encoded,
        f.rank,
        f.list_updated,
        a.author_key,
        f.author_full_name
    FROM flattened AS f
    INNER JOIN {{ ref('dim_authors') }} AS a
        ON f.author_full_name = a.author_full_name
)

SELECT * FROM with_key
