WITH articles AS (
    SELECT * FROM {{ ref('fct_articles') }}
),

yearly_totals AS (
    SELECT
        pub_year,
        count(*) AS year_total
    FROM articles
    GROUP BY 1
),

section_yearly AS (
    SELECT
        a.section_name,
        a.news_desk,
        a.pub_year,

        count(*) AS article_count,
        avg(a.word_count) AS avg_word_count,
        sum(a.word_count) AS total_word_count,

        countif(a.has_authors) AS articles_with_authors,
        countif(a.has_keywords) AS articles_with_keywords,

        avg(a.author_count) AS avg_authors,
        avg(a.keyword_count) AS avg_keywords

    FROM articles AS a
    GROUP BY 1, 2, 3
),

with_percentages AS (
    SELECT
        sy.*,
        yt.year_total,
        round(100.0 * sy.article_count / nullif(yt.year_total, 0), 2) AS pct_of_year_total,

        -- Year-over-year change
        lag(sy.article_count) OVER (
            PARTITION BY sy.section_name, sy.news_desk
            ORDER BY sy.pub_year
        ) AS prior_year_count

    FROM section_yearly AS sy
    LEFT JOIN yearly_totals AS yt ON sy.pub_year = yt.pub_year
),

final AS (
    SELECT
        section_name,
        news_desk,
        pub_year,

        article_count,
        year_total,
        pct_of_year_total,

        round(avg_word_count, 0) AS avg_word_count,
        total_word_count,

        articles_with_authors,
        articles_with_keywords,

        round(avg_authors, 2) AS avg_authors,
        round(avg_keywords, 2) AS avg_keywords,

        prior_year_count,
        article_count - coalesce(prior_year_count, 0) AS yoy_change,
        CASE
            WHEN prior_year_count > 0
                THEN round(100.0 * (article_count - prior_year_count) / prior_year_count, 1)
        END AS yoy_change_pct

    FROM with_percentages
    ORDER BY with_percentages.pub_year ASC, with_percentages.article_count DESC
)

SELECT * FROM final
