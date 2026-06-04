WITH articles AS (
    SELECT * FROM {{ ref('fct_articles') }}
),

monthly_stats AS (
    SELECT
        date_trunc(pub_date, MONTH) AS pub_month,

        -- Counts
        count(*) AS total_articles,

        -- Word count metrics
        avg(word_count) AS avg_word_count,
        sum(word_count) AS total_word_count,
        max(word_count) AS max_word_count,

        -- Content richness
        countif(has_authors) AS articles_with_authors,
        countif(has_keywords) AS articles_with_keywords,
        countif(has_multimedia) AS articles_with_multimedia,

        -- Author metrics
        avg(author_count) AS avg_authors_per_article,
        sum(author_count) AS total_author_appearances,

        -- Keyword metrics
        avg(keyword_count) AS avg_keywords_per_article,
        sum(keyword_count) AS total_keywords,

        -- Section diversity
        count(DISTINCT section_name) AS unique_sections,
        count(DISTINCT news_desk) AS unique_news_desks,

        -- Material types
        count(DISTINCT type_of_material) AS unique_material_types

    FROM articles
    GROUP BY 1
),

final AS (
    SELECT
        pub_month,
        total_articles,

        round(avg_word_count, 0) AS avg_word_count,
        total_word_count,
        max_word_count,

        articles_with_authors,
        articles_with_keywords,
        articles_with_multimedia,

        round(avg_authors_per_article, 2) AS avg_authors_per_article,
        round(avg_keywords_per_article, 2) AS avg_keywords_per_article,

        unique_sections,
        unique_news_desks,
        unique_material_types,

        -- Percentages
        round(100.0 * articles_with_authors / nullif(total_articles, 0), 1) AS pct_with_authors,
        round(100.0 * articles_with_keywords / nullif(total_articles, 0), 1) AS pct_with_keywords,
        round(100.0 * articles_with_multimedia / nullif(total_articles, 0), 1)
            AS pct_with_multimedia

    FROM monthly_stats
    ORDER BY monthly_stats.pub_month
)

SELECT * FROM final
