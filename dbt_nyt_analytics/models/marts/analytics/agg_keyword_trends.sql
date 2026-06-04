WITH keywords AS (
    SELECT
        b.article_id,
        b.keyword_name,
        b.keyword_value,
        f.pub_year
    FROM {{ ref('bridge_article_keywords') }} AS b
    INNER JOIN {{ ref('fct_articles') }} AS f
        ON b.article_id = f.article_id
),

yearly_keyword_stats AS (
    SELECT
        keyword_name,
        keyword_value,
        pub_year,

        count(DISTINCT article_id) AS article_count,
        count(*) AS keyword_occurrences

    FROM keywords
    GROUP BY 1, 2, 3
),

with_rankings AS (
    SELECT
        *,

        -- Rank within year
        row_number() OVER (
            PARTITION BY pub_year
            ORDER BY article_count DESC
        ) AS rank_in_year,

        -- Prior year article count
        lag(article_count) OVER (
            PARTITION BY keyword_name, keyword_value
            ORDER BY pub_year
        ) AS prior_year_count

    FROM yearly_keyword_stats
),

with_prior_rank AS (
    SELECT
        *,

        -- Get prior year rank by using lag on the already computed rank_in_year
        lag(rank_in_year) OVER (
            PARTITION BY keyword_name, keyword_value
            ORDER BY pub_year
        ) AS prior_year_rank

    FROM with_rankings
),

final AS (
    SELECT
        keyword_name,
        keyword_value,
        pub_year,

        article_count,
        keyword_occurrences,
        rank_in_year,

        prior_year_count,
        article_count - coalesce(prior_year_count, 0) AS yoy_change,
        CASE
            WHEN prior_year_count > 0
                THEN round(100.0 * (article_count - prior_year_count) / prior_year_count, 1)
        END AS yoy_change_pct,

        prior_year_rank,
        coalesce(prior_year_rank, 0) - rank_in_year AS rank_change

    FROM with_prior_rank
    ORDER BY with_prior_rank.pub_year DESC, with_prior_rank.article_count DESC
)

SELECT * FROM final
