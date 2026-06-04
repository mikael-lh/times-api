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
        count(DISTINCT article_id) AS total_articles,

        -- Date range
        min(pub_date) AS first_article_date,
        max(pub_date) AS last_article_date,
        date_diff(max(pub_date), min(pub_date), DAY) AS career_span_days,

        -- Years active
        count(DISTINCT pub_year) AS years_active,
        min(pub_year) AS first_year,
        max(pub_year) AS last_year,

        -- Content metrics
        avg(word_count) AS avg_word_count,
        sum(word_count) AS total_words_written,
        max(word_count) AS longest_article_words,

        -- Topic diversity
        count(DISTINCT section_name) AS sections_written_for,
        avg(keyword_count) AS avg_keywords_per_article

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

        round(avg_word_count, 0) AS avg_word_count,
        total_words_written,
        longest_article_words,

        sections_written_for,
        round(avg_keywords_per_article, 1) AS avg_keywords_per_article,

        -- Productivity metric
        round(total_articles / nullif(years_active, 0), 1) AS articles_per_year

    FROM author_stats
    ORDER BY author_stats.total_articles DESC
)

SELECT * FROM final
