WITH flattened AS (
    SELECT
        article_id,
        facet_type,
        facet_value
    FROM {{ ref('int_facets_flattened') }}
),

with_key AS (
    SELECT
        f.article_id,
        df.facet_key,
        f.facet_type,
        f.facet_value
    FROM flattened AS f
    INNER JOIN {{ ref('dim_facets') }} AS df
        ON
            f.facet_type = df.facet_type
            AND f.facet_value = df.facet_value
)

SELECT * FROM with_key
