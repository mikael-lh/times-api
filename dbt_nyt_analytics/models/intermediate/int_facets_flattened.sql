WITH staged AS (
    SELECT
        article_id,
        des_facet,
        org_facet,
        per_facet,
        geo_facet
    FROM {{ ref('stg_most_popular_articles') }}
),

unioned AS (
    SELECT
        article_id,
        'description' AS facet_type,
        TRIM(facet) AS facet_value
    FROM staged,
        UNNEST(des_facet) AS facet
    WHERE facet IS NOT NULL AND TRIM(facet) != ''

    UNION DISTINCT

    SELECT
        article_id,
        'organization' AS facet_type,
        TRIM(facet) AS facet_value
    FROM staged,
        UNNEST(org_facet) AS facet
    WHERE facet IS NOT NULL AND TRIM(facet) != ''

    UNION DISTINCT

    SELECT
        article_id,
        'person' AS facet_type,
        TRIM(facet) AS facet_value
    FROM staged,
        UNNEST(per_facet) AS facet
    WHERE facet IS NOT NULL AND TRIM(facet) != ''

    UNION DISTINCT

    SELECT
        article_id,
        'geographic' AS facet_type,
        TRIM(facet) AS facet_value
    FROM staged,
        UNNEST(geo_facet) AS facet
    WHERE facet IS NOT NULL AND TRIM(facet) != ''
)

SELECT * FROM unioned
