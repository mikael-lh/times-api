WITH unique_facets AS (
    SELECT DISTINCT
        facet_type,
        facet_value
    FROM {{ ref('int_facets_flattened') }}
),

with_key AS (
    SELECT
        {{ generate_surrogate_key(['facet_type', 'facet_value']) }} AS facet_key,
        facet_type,
        facet_value
    FROM unique_facets
)

SELECT * FROM with_key
