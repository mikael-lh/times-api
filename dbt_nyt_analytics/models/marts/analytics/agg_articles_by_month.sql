WITH articles AS (
    SELECT * FROM {{ ref('fct_articles') }}
),

monthly_stats AS (
    SELECT
        DATE_TRUNC(pub_date, MONTH) AS pub_month,

        -- Counts
        COUNT(*) AS total_articles,

        -- Word count metrics
        AVG(word_count) AS avg_word_count,
        SUM(word_count) AS total_word_count,
        MAX(word_count) AS max_word_count,

        -- Content richness
        COUNTIF(has_authors) AS articles_with_authors,
        COUNTIF(has_keywords) AS articles_with_keywords,
        COUNTIF(has_multimedia) AS articles_with_multimedia,

        -- Author metrics
        AVG(author_count) AS avg_authors_per_article,
        SUM(author_count) AS total_author_appearances,

        -- Keyword metrics
        AVG(keyword_count) AS avg_keywords_per_article,
        SUM(keyword_count) AS total_keywords,

        -- Section diversity
        COUNT(DISTINCT section_name) AS unique_sections,
        COUNT(DISTINCT news_desk) AS unique_news_desks,

        -- Material types
        COUNT(DISTINCT type_of_material) AS unique_material_types

    FROM articles
    GROUP BY 1
),

final AS (
    SELECT
        pub_month,
        total_articles,

        ROUND(avg_word_count, 0) AS avg_word_count,
        total_word_count,
        max_word_count,

        articles_with_authors,
        articles_with_keywords,
        articles_with_multimedia,

        ROUND(avg_authors_per_article, 2) AS avg_authors_per_article,
        ROUND(avg_keywords_per_article, 2) AS avg_keywords_per_article,

        unique_sections,
        unique_news_desks,
        unique_material_types,

        -- Percentages
        ROUND(100.0 * articles_with_authors / NULLIF(total_articles, 0), 1) AS pct_with_authors,
        ROUND(100.0 * articles_with_keywords / NULLIF(total_articles, 0), 1) AS pct_with_keywords,
        ROUND(100.0 * articles_with_multimedia / NULLIF(total_articles, 0), 1)
            AS pct_with_multimedia

    FROM monthly_stats
    ORDER BY monthly_stats.pub_month
)

SELECT * FROM final
