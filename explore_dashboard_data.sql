-- NYT Analytics Dashboard - Exploratory Data Analysis Queries
-- Run these queries in BigQuery to explore the data and validate dashboard concepts
-- Replace project ID if different from: times-api-ingest

-- ============================================================================
-- 1. DATA OVERVIEW & PROFILING
-- ============================================================================

-- Overall data statistics
SELECT 
  'fct_articles' as table_name,
  COUNT(*) as total_records,
  MIN(pub_date) as earliest_date,
  MAX(pub_date) as latest_date,
  COUNT(DISTINCT section_name) as unique_sections,
  COUNT(DISTINCT news_desk) as unique_desks,
  ROUND(AVG(word_count), 0) as avg_word_count,
  ROUND(AVG(author_count), 2) as avg_author_count,
  ROUND(AVG(keyword_count), 2) as avg_keyword_count
FROM `times-api-ingest.dbt_core.fct_articles`;

-- Most popular articles data statistics
SELECT 
  'fct_article_popularity' as table_name,
  COUNT(*) as total_records,
  MIN(snapshot_date) as earliest_snapshot,
  MAX(snapshot_date) as latest_snapshot,
  COUNT(DISTINCT article_id) as unique_articles,
  ROUND(AVG(days_since_published), 1) as avg_days_since_published
FROM `times-api-ingest.dbt_core.fct_article_popularity`;

-- ============================================================================
-- 2. CONTENT EVOLUTION ANALYSIS
-- ============================================================================

-- Articles published by year (high-level trend)
SELECT 
  pub_year,
  COUNT(*) as article_count,
  ROUND(AVG(word_count), 0) as avg_word_count,
  COUNT(DISTINCT section_name) as sections_active
FROM `times-api-ingest.dbt_core.fct_articles`
GROUP BY pub_year
ORDER BY pub_year DESC
LIMIT 50;

-- Monthly publishing trends (recent 5 years)
SELECT 
  pub_month,
  total_articles,
  avg_word_count,
  pct_with_authors,
  pct_with_keywords,
  pct_with_multimedia,
  unique_sections
FROM `times-api-ingest.dbt_analytics.agg_articles_by_month`
WHERE pub_month >= DATE_SUB(CURRENT_DATE(), INTERVAL 5 YEAR)
ORDER BY pub_month DESC;

-- Busiest publishing months in history
SELECT 
  pub_month,
  total_articles,
  avg_word_count,
  unique_sections,
  -- Add context about what might have driven volume
  EXTRACT(YEAR FROM pub_month) as year,
  EXTRACT(MONTH FROM pub_month) as month
FROM `times-api-ingest.dbt_analytics.agg_articles_by_month`
ORDER BY total_articles DESC
LIMIT 20;

-- Word count evolution by decade
SELECT 
  FLOOR(pub_year / 10) * 10 as decade,
  COUNT(*) as article_count,
  ROUND(AVG(word_count), 0) as avg_word_count,
  ROUND(STDDEV(word_count), 0) as stddev_word_count,
  MIN(word_count) as min_word_count,
  MAX(word_count) as max_word_count
FROM `times-api-ingest.dbt_core.fct_articles`
GROUP BY decade
ORDER BY decade;

-- ============================================================================
-- 3. SECTION & COVERAGE ANALYSIS
-- ============================================================================

-- Top sections (all time)
SELECT 
  section_name,
  COUNT(*) as article_count,
  ROUND(AVG(word_count), 0) as avg_word_count,
  COUNT(DISTINCT pub_year) as years_active,
  MIN(pub_date) as first_article,
  MAX(pub_date) as last_article
FROM `times-api-ingest.dbt_core.fct_articles`
GROUP BY section_name
ORDER BY article_count DESC
LIMIT 30;

-- Section growth/decline (last year)
SELECT 
  section_name,
  pub_year,
  article_count,
  prior_year_count,
  yoy_change,
  yoy_change_pct,
  pct_of_year_total
FROM `times-api-ingest.dbt_analytics.agg_section_trends`
WHERE pub_year = EXTRACT(YEAR FROM CURRENT_DATE()) - 1
ORDER BY yoy_change_pct DESC
LIMIT 30;

-- Section composition by decade
SELECT 
  FLOOR(pub_year / 10) * 10 as decade,
  section_name,
  SUM(article_count) as total_articles,
  ROUND(AVG(avg_word_count), 0) as avg_word_count
FROM `times-api-ingest.dbt_analytics.agg_section_trends`
GROUP BY decade, section_name
HAVING SUM(article_count) > 1000  -- Filter noise
ORDER BY decade DESC, total_articles DESC;

-- News desks overview
SELECT 
  news_desk,
  COUNT(*) as article_count,
  COUNT(DISTINCT section_name) as sections_covered,
  ROUND(AVG(word_count), 0) as avg_word_count,
  MIN(pub_date) as first_article,
  MAX(pub_date) as last_article
FROM `times-api-ingest.dbt_core.fct_articles`
GROUP BY news_desk
ORDER BY article_count DESC
LIMIT 30;

-- ============================================================================
-- 4. KEYWORD & TOPIC TRENDS
-- ============================================================================

-- Top keywords (all time)
SELECT 
  keyword_value,
  keyword_name,
  SUM(article_count) as total_articles,
  MIN(pub_year) as first_appeared,
  MAX(pub_year) as last_appeared,
  COUNT(DISTINCT pub_year) as years_active
FROM `times-api-ingest.dbt_analytics.agg_keyword_trends`
GROUP BY keyword_value, keyword_name
ORDER BY total_articles DESC
LIMIT 50;

-- Top keywords (last 5 years)
SELECT 
  keyword_value,
  keyword_name,
  SUM(article_count) as total_articles,
  AVG(article_count) as avg_articles_per_year
FROM `times-api-ingest.dbt_analytics.agg_keyword_trends`
WHERE pub_year >= EXTRACT(YEAR FROM CURRENT_DATE()) - 5
GROUP BY keyword_value, keyword_name
ORDER BY total_articles DESC
LIMIT 50;

-- Fastest growing keywords (recent years)
SELECT 
  keyword_value,
  keyword_name,
  pub_year,
  article_count,
  prior_year_count,
  yoy_change,
  yoy_change_pct,
  rank_in_year
FROM `times-api-ingest.dbt_analytics.agg_keyword_trends`
WHERE pub_year IN (
  EXTRACT(YEAR FROM CURRENT_DATE()) - 1,
  EXTRACT(YEAR FROM CURRENT_DATE()) - 2
)
  AND article_count > 50  -- Significant volume
  AND yoy_change_pct > 100  -- At least doubled
ORDER BY yoy_change_pct DESC
LIMIT 30;

-- Keywords that dominated each decade (top 5 per decade)
WITH ranked_keywords AS (
  SELECT 
    FLOOR(pub_year / 10) * 10 as decade,
    keyword_value,
    SUM(article_count) as total_articles,
    ROW_NUMBER() OVER (
      PARTITION BY FLOOR(pub_year / 10) * 10 
      ORDER BY SUM(article_count) DESC
    ) as rank_in_decade
  FROM `times-api-ingest.dbt_analytics.agg_keyword_trends`
  GROUP BY decade, keyword_value
)
SELECT 
  decade,
  keyword_value,
  total_articles,
  rank_in_decade
FROM ranked_keywords
WHERE rank_in_decade <= 5
ORDER BY decade DESC, rank_in_decade;

-- Track specific keywords over time (COVID, Trump, Climate, AI)
SELECT 
  keyword_value,
  pub_year,
  article_count,
  rank_in_year
FROM `times-api-ingest.dbt_analytics.agg_keyword_trends`
WHERE LOWER(keyword_value) IN (
  'covid-19', 'coronavirus', 'pandemic',
  'trump', 'trump, donald j',
  'climate change', 'global warming',
  'artificial intelligence', 'ai'
)
ORDER BY keyword_value, pub_year;

-- ============================================================================
-- 5. AUTHOR ANALYTICS
-- ============================================================================

-- Most prolific authors (all time)
SELECT 
  author_full_name,
  total_articles,
  first_article_date,
  last_article_date,
  years_active,
  articles_per_year,
  avg_word_count,
  total_words_written,
  sections_written_for,
  first_year,
  last_year
FROM `times-api-ingest.dbt_analytics.agg_author_performance`
ORDER BY total_articles DESC
LIMIT 50;

-- Most productive authors (articles per year)
SELECT 
  author_full_name,
  total_articles,
  years_active,
  articles_per_year,
  first_year,
  last_year
FROM `times-api-ingest.dbt_analytics.agg_author_performance`
WHERE years_active >= 5  -- At least 5 years active
ORDER BY articles_per_year DESC
LIMIT 30;

-- Most versatile authors (cover many sections)
SELECT 
  author_full_name,
  sections_written_for,
  total_articles,
  years_active,
  avg_word_count
FROM `times-api-ingest.dbt_analytics.agg_author_performance`
ORDER BY sections_written_for DESC, total_articles DESC
LIMIT 30;

-- Longest serving authors (career span)
SELECT 
  author_full_name,
  first_year,
  last_year,
  years_active,
  career_span_days,
  total_articles,
  articles_per_year
FROM `times-api-ingest.dbt_analytics.agg_author_performance`
ORDER BY career_span_days DESC
LIMIT 30;

-- Authors who wrote the longest articles
SELECT 
  author_full_name,
  longest_article_words,
  avg_word_count,
  total_articles
FROM `times-api-ingest.dbt_analytics.agg_author_performance`
ORDER BY longest_article_words DESC
LIMIT 30;

-- Author debut by decade
SELECT 
  FLOOR(first_year / 10) * 10 as debut_decade,
  COUNT(*) as new_authors
FROM `times-api-ingest.dbt_analytics.agg_author_performance`
GROUP BY debut_decade
ORDER BY debut_decade;

-- ============================================================================
-- 6. POPULARITY & VIRALITY ANALYSIS
-- ============================================================================

-- Most recent popular articles (last 7 days)
SELECT 
  p.snapshot_date,
  p.title,
  p.section,
  p.published_date,
  p.days_since_published,
  p.url,
  p.byline,
  p.description_facet_count,
  p.person_facet_count,
  p.geo_facet_count
FROM `times-api-ingest.dbt_core.fct_article_popularity` p
WHERE p.snapshot_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
ORDER BY p.snapshot_date DESC, p.days_since_published ASC
LIMIT 100;

-- Time to popularity distribution
SELECT 
  CASE 
    WHEN days_since_published = 0 THEN '0 days (same day)'
    WHEN days_since_published BETWEEN 1 AND 7 THEN '1-7 days'
    WHEN days_since_published BETWEEN 8 AND 30 THEN '8-30 days'
    WHEN days_since_published BETWEEN 31 AND 365 THEN '31-365 days'
    ELSE '365+ days (evergreen)'
  END as age_bucket,
  COUNT(*) as article_count,
  ROUND(AVG(days_since_published), 1) as avg_days_old
FROM `times-api-ingest.dbt_core.fct_article_popularity`
GROUP BY age_bucket
ORDER BY MIN(days_since_published);

-- Evergreen articles (popular long after publication)
SELECT 
  p.title,
  p.section,
  p.published_date,
  p.snapshot_date,
  p.days_since_published,
  p.url
FROM `times-api-ingest.dbt_core.fct_article_popularity` p
WHERE p.days_since_published > 365
ORDER BY p.days_since_published DESC
LIMIT 50;

-- Sections that produce the most viral content
SELECT 
  section,
  COUNT(DISTINCT article_id) as unique_popular_articles,
  COUNT(*) as total_appearances,
  ROUND(AVG(days_since_published), 1) as avg_age_when_popular
FROM `times-api-ingest.dbt_core.fct_article_popularity`
GROUP BY section
ORDER BY unique_popular_articles DESC;

-- Popular articles by facet richness (more facets = more viral?)
SELECT 
  CASE 
    WHEN description_facet_count + geo_facet_count + person_facet_count = 0 THEN 'No facets'
    WHEN description_facet_count + geo_facet_count + person_facet_count BETWEEN 1 AND 5 THEN '1-5 facets'
    WHEN description_facet_count + geo_facet_count + person_facet_count BETWEEN 6 AND 10 THEN '6-10 facets'
    ELSE '11+ facets'
  END as facet_bucket,
  COUNT(*) as article_count,
  ROUND(AVG(description_facet_count), 1) as avg_description_facets,
  ROUND(AVG(geo_facet_count), 1) as avg_geo_facets,
  ROUND(AVG(person_facet_count), 1) as avg_person_facets
FROM `times-api-ingest.dbt_core.fct_article_popularity`
GROUP BY facet_bucket
ORDER BY MIN(description_facet_count + geo_facet_count + person_facet_count);

-- ============================================================================
-- 7. HISTORICAL EVENT ANALYSIS
-- ============================================================================

-- Publishing volume during specific years (major events)
SELECT 
  pub_year,
  COUNT(*) as article_count,
  ROUND(AVG(word_count), 0) as avg_word_count,
  COUNT(DISTINCT section_name) as sections_active,
  -- Context
  CASE 
    WHEN pub_year BETWEEN 1914 AND 1918 THEN 'WWI'
    WHEN pub_year BETWEEN 1939 AND 1945 THEN 'WWII'
    WHEN pub_year = 1929 THEN 'Great Depression Begins'
    WHEN pub_year = 1963 THEN 'JFK Assassination'
    WHEN pub_year = 2001 THEN '9/11'
    WHEN pub_year = 2008 THEN 'Financial Crisis'
    WHEN pub_year = 2020 THEN 'COVID-19 Pandemic'
    WHEN pub_year IN (2016, 2020, 2024) THEN 'Presidential Election'
    ELSE NULL
  END as historical_context
FROM `times-api-ingest.dbt_core.fct_articles`
WHERE pub_year IN (
  1914, 1918, 1929, 1939, 1945, 1963, 
  2001, 2008, 2016, 2020, 2024
)
GROUP BY pub_year
ORDER BY pub_year;

-- COVID coverage evolution (2019-2023)
SELECT 
  pub_year,
  keyword_value,
  article_count,
  rank_in_year,
  yoy_change_pct
FROM `times-api-ingest.dbt_analytics.agg_keyword_trends`
WHERE LOWER(keyword_value) LIKE '%covid%'
  OR LOWER(keyword_value) LIKE '%coronavirus%'
  OR LOWER(keyword_value) LIKE '%pandemic%'
ORDER BY pub_year, article_count DESC;

-- ============================================================================
-- 8. CONTENT QUALITY & RICHNESS METRICS
-- ============================================================================

-- Collaboration trends (multi-author articles)
SELECT 
  CASE 
    WHEN author_count = 0 THEN 'No attribution'
    WHEN author_count = 1 THEN 'Single author'
    WHEN author_count = 2 THEN '2 authors'
    WHEN author_count = 3 THEN '3 authors'
    ELSE '4+ authors'
  END as author_bucket,
  COUNT(*) as article_count,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) as pct_of_total
FROM `times-api-ingest.dbt_core.fct_articles`
GROUP BY author_bucket
ORDER BY MIN(author_count);

-- Collaboration trends over time
SELECT 
  pub_year,
  COUNT(*) as total_articles,
  COUNTIF(author_count = 0) as no_author,
  COUNTIF(author_count = 1) as single_author,
  COUNTIF(author_count = 2) as two_authors,
  COUNTIF(author_count >= 3) as three_plus_authors,
  ROUND(100.0 * COUNTIF(author_count >= 2) / COUNT(*), 2) as pct_collaborative
FROM `times-api-ingest.dbt_core.fct_articles`
GROUP BY pub_year
ORDER BY pub_year DESC
LIMIT 50;

-- Keyword density by section
SELECT 
  section_name,
  COUNT(*) as article_count,
  ROUND(AVG(keyword_count), 2) as avg_keywords,
  ROUND(AVG(major_keyword_count), 2) as avg_major_keywords,
  ROUND(100.0 * COUNTIF(has_keywords) / COUNT(*), 2) as pct_with_keywords
FROM `times-api-ingest.dbt_core.fct_articles`
GROUP BY section_name
HAVING COUNT(*) > 1000
ORDER BY avg_keywords DESC;

-- Word count distribution by section (for box plots)
SELECT 
  section_name,
  COUNT(*) as article_count,
  MIN(word_count) as min_words,
  APPROX_QUANTILES(word_count, 100)[OFFSET(25)] as p25_words,
  APPROX_QUANTILES(word_count, 100)[OFFSET(50)] as median_words,
  APPROX_QUANTILES(word_count, 100)[OFFSET(75)] as p75_words,
  MAX(word_count) as max_words,
  ROUND(AVG(word_count), 0) as avg_words
FROM `times-api-ingest.dbt_core.fct_articles`
GROUP BY section_name
HAVING COUNT(*) > 1000
ORDER BY median_words DESC;

-- ============================================================================
-- 9. ANOMALY DETECTION
-- ============================================================================

-- Unusual publishing spikes (months with >3 std dev from mean)
WITH monthly_stats AS (
  SELECT 
    AVG(total_articles) as mean_articles,
    STDDEV(total_articles) as stddev_articles
  FROM `times-api-ingest.dbt_analytics.agg_articles_by_month`
)
SELECT 
  m.pub_month,
  m.total_articles,
  s.mean_articles,
  s.stddev_articles,
  ROUND((m.total_articles - s.mean_articles) / s.stddev_articles, 2) as z_score
FROM `times-api-ingest.dbt_analytics.agg_articles_by_month` m
CROSS JOIN monthly_stats s
WHERE ABS((m.total_articles - s.mean_articles) / s.stddev_articles) > 3
ORDER BY ABS((m.total_articles - s.mean_articles) / s.stddev_articles) DESC;

-- Keywords that appeared suddenly (not in previous years)
WITH keyword_years AS (
  SELECT 
    keyword_value,
    keyword_name,
    pub_year,
    article_count,
    LAG(article_count, 1) OVER (PARTITION BY keyword_value ORDER BY pub_year) as prev_year,
    LAG(article_count, 2) OVER (PARTITION BY keyword_value ORDER BY pub_year) as two_years_ago
  FROM `times-api-ingest.dbt_analytics.agg_keyword_trends`
)
SELECT 
  keyword_value,
  keyword_name,
  pub_year as first_year,
  article_count as first_year_count
FROM keyword_years
WHERE prev_year IS NULL 
  AND two_years_ago IS NULL
  AND article_count > 100
ORDER BY article_count DESC
LIMIT 50;

-- ============================================================================
-- 10. DASHBOARD-READY QUERIES (Pre-Aggregated)
-- ============================================================================

-- Daily trending summary (for dashboard landing page)
SELECT 
  CURRENT_DATE() as as_of_date,
  COUNT(DISTINCT article_id) as trending_articles_count,
  ROUND(AVG(days_since_published), 1) as avg_article_age,
  COUNT(DISTINCT section) as sections_represented,
  ARRAY_AGG(DISTINCT section ORDER BY section LIMIT 10) as top_sections
FROM `times-api-ingest.dbt_core.fct_article_popularity`
WHERE snapshot_date = (
  SELECT MAX(snapshot_date) 
  FROM `times-api-ingest.dbt_core.fct_article_popularity`
);

-- Key metrics summary (for dashboard header)
SELECT 
  (SELECT COUNT(*) FROM `times-api-ingest.dbt_core.fct_articles`) as total_articles,
  (SELECT COUNT(*) FROM `times-api-ingest.dbt_analytics.agg_author_performance`) as total_authors,
  (SELECT COUNT(DISTINCT section_name) FROM `times-api-ingest.dbt_core.fct_articles`) as total_sections,
  (SELECT DATE_DIFF(MAX(pub_date), MIN(pub_date), YEAR) FROM `times-api-ingest.dbt_core.fct_articles`) as years_of_coverage,
  (SELECT MAX(pub_date) FROM `times-api-ingest.dbt_core.fct_articles`) as latest_article_date,
  (SELECT MAX(snapshot_date) FROM `times-api-ingest.dbt_core.fct_article_popularity`) as latest_snapshot_date;

-- Recent trends sparkline data (last 12 months)
SELECT 
  pub_month,
  total_articles,
  avg_word_count,
  pct_with_keywords,
  unique_sections
FROM `times-api-ingest.dbt_analytics.agg_articles_by_month`
WHERE pub_month >= DATE_SUB(CURRENT_DATE(), INTERVAL 12 MONTH)
ORDER BY pub_month;
