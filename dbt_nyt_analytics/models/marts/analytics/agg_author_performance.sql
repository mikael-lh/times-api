WITH author_articles AS (
    SELECT
        af.author_full_name,
        af.firstname,
        af.lastname,
        af.article_id,
        af.pub_date,
        af.pub_year,
        af.section_name,
        fa.word_count,
        fa.keyword_count
    FROM {{ ref('int_authors_flattened') }} AS af
    INNER JOIN {{ ref('fct_articles') }} AS fa ON af.article_id = fa.article_id
),

author_stats AS (
    SELECT
        author_full_name,
        firstname,
        lastname,

        -- Article counts
        COUNT(DISTINCT article_id) AS total_articles,

        -- Date range
        MIN(pub_date) AS first_article_date,
        MAX(pub_date) AS last_article_date,
        DATE_DIFF(MAX(pub_date), MIN(pub_date), DAY) AS career_span_days,

        -- Years active
        COUNT(DISTINCT pub_year) AS years_active,
        MIN(pub_year) AS first_year,
        MAX(pub_year) AS last_year,

        -- Content metrics
        AVG(word_count) AS avg_word_count,
        SUM(word_count) AS total_words_written,
        MAX(word_count) AS longest_article_words,

        -- Topic diversity
        COUNT(DISTINCT section_name) AS sections_written_for,
        AVG(keyword_count) AS avg_keywords_per_article

    FROM author_articles
    GROUP BY 1, 2, 3
),

final AS (
    SELECT
        author_full_name,
        firstname,
        lastname,

        total_articles,
        first_article_date,
        last_article_date,
        career_span_days,

        years_active,
        first_year,
        last_year,

        ROUND(avg_word_count, 0) AS avg_word_count,
        total_words_written,
        longest_article_words,

        sections_written_for,
        ROUND(avg_keywords_per_article, 1) AS avg_keywords_per_article,

        -- Productivity metric
        ROUND(total_articles / NULLIF(years_active, 0), 1) AS articles_per_year

    FROM author_stats
    ORDER BY author_stats.total_articles DESC
)

SELECT * FROM final
