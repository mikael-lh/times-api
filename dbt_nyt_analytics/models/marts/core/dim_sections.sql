WITH sections AS (
    SELECT DISTINCT
        section_name,
        news_desk
    FROM {{ ref('stg_archive_articles') }}
),

with_key AS (
    SELECT
        {{ generate_surrogate_key(['section_name', 'news_desk']) }} AS section_key,
        section_name,
        news_desk
    FROM sections
)

SELECT * FROM with_key
