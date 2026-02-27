# NYT Analytics Dashboard - EDA & Insights Analysis

## Executive Summary

This document outlines potential insights and dashboard visualizations based on the dbt models created for NYT article data (1851-present + daily most popular articles).

---

## Data Sources Available

### Primary Fact Tables
1. **`fct_articles`** - Core archive articles with metrics (incremental, partitioned by `pub_date`)
2. **`fct_article_popularity`** - Daily popularity snapshots (tracks trending articles)

### Dimension Tables
1. **`dim_authors`** - Unique authors
2. **`dim_keywords`** - Unique keywords/topics
3. **`dim_sections`** - Sections and news desks

### Analytics Aggregations
1. **`agg_articles_by_month`** - Monthly content trends
2. **`agg_author_performance`** - Author productivity and career metrics
3. **`agg_section_trends`** - Section evolution by year
4. **`agg_keyword_trends`** - Topic/keyword trends with YoY changes

---

## Dashboard Concepts & Insights

### 1. **Content Production Dashboard**

#### Insight: "The Evolution of NYT Publishing"

**Key Metrics:**
- Total articles published per month/year (1851-present)
- Average word count trends over time
- Content richness (% articles with authors, keywords, multimedia)

**Visualizations:**
```
📊 Line Chart: Articles Published Over Time (Monthly)
   - X-axis: pub_month
   - Y-axis: total_articles
   - Source: agg_articles_by_month
   
📊 Area Chart: Content Richness Trends
   - X-axis: pub_month
   - Y-axis: pct_with_authors, pct_with_keywords, pct_with_multimedia
   - Source: agg_articles_by_month
   
📊 Line Chart: Average Word Count Evolution
   - X-axis: pub_month
   - Y-axis: avg_word_count
   - Shows how article length has changed over decades
```

**Questions Answered:**
- How has NYT's publishing volume changed over 170+ years?
- Are articles getting shorter or longer over time?
- When did multimedia integration become prominent?

---

### 2. **Section & News Desk Analysis Dashboard**

#### Insight: "What NYT Covers & How It's Changed"

**Key Metrics:**
- Top sections by article count (yearly)
- Section market share (% of total articles)
- YoY growth by section
- News desk productivity

**Visualizations:**
```
📊 Stacked Area Chart: Section Composition Over Time
   - X-axis: pub_year
   - Y-axis: article_count (stacked by section_name)
   - Source: agg_section_trends
   
📊 Tree Map: Current Year Section Distribution
   - Size: article_count (latest year)
   - Color: yoy_change_pct
   - Source: agg_section_trends WHERE pub_year = MAX(pub_year)
   
📊 Bar Chart: Top Growing/Declining Sections
   - X-axis: section_name
   - Y-axis: yoy_change_pct
   - Filter: Latest year, sorted by YoY change
   
📊 Heatmap: Section Activity by Year
   - X-axis: pub_year
   - Y-axis: section_name
   - Color intensity: article_count
```

**Questions Answered:**
- Which sections have grown or declined over time?
- What's the current composition of NYT coverage?
- How has the news desk structure evolved?

---

### 3. **Topic & Keyword Trends Dashboard**

#### Insight: "What's Being Talked About"

**Key Metrics:**
- Top keywords by year
- Emerging topics (keywords with highest YoY growth)
- Declining topics (keywords losing coverage)
- Keyword rank changes over time

**Visualizations:**
```
📊 Bump Chart: Top 10 Keywords Rank Over Time
   - X-axis: pub_year
   - Y-axis: rank_in_year (inverted, so rank 1 is at top)
   - Lines: keyword_value (top 10 from latest year)
   - Source: agg_keyword_trends
   
📊 Bar Chart (Racing): Top 20 Keywords by Year
   - Animated bar chart showing keyword_value vs article_count
   - Animation: pub_year (1851 → present)
   
📊 Scatter Plot: Keyword Momentum
   - X-axis: article_count (current year)
   - Y-axis: yoy_change_pct
   - Bubble size: keyword_occurrences
   - Quadrants: "Rising Stars", "Established", "Declining", "Niche"
   
📊 Word Cloud: Current Year Top Keywords
   - Size: article_count
   - Source: agg_keyword_trends WHERE pub_year = MAX(pub_year)
```

**Questions Answered:**
- What topics are surging in coverage?
- Which keywords have stood the test of time?
- What topics are losing relevance?
- Can we identify news cycles (e.g., election years, wars)?

**Specific Analyses:**
- Track keywords like "COVID-19", "Trump", "Climate", "AI", "Ukraine" over time
- Identify decade-defining topics (1920s: Prohibition, 1960s: Vietnam, etc.)

---

### 4. **Author Analytics Dashboard**

#### Insight: "The People Behind the Stories"

**Key Metrics:**
- Most prolific authors (total_articles)
- Author career spans (career_span_days, years_active)
- Writing styles (avg_word_count per author)
- Topic diversity (sections_written_for)
- Productivity (articles_per_year)

**Visualizations:**
```
📊 Table: Top 50 Authors Leaderboard
   - Columns: author_full_name, total_articles, total_words_written,
     first_year, last_year, years_active, articles_per_year
   - Sortable, searchable
   - Source: agg_author_performance
   
📊 Scatter Plot: Author Productivity vs Longevity
   - X-axis: years_active
   - Y-axis: articles_per_year
   - Bubble size: total_articles
   - Color: sections_written_for (topic diversity)
   
📊 Histogram: Author Career Spans
   - X-axis: years_active (binned)
   - Y-axis: count of authors
   - Shows distribution of career lengths
   
📊 Bar Chart: Most Versatile Authors
   - X-axis: author_full_name (top 20)
   - Y-axis: sections_written_for
   - Shows authors who cover the most diverse topics
```

**Questions Answered:**
- Who are the most prolific NYT authors of all time?
- What's the typical career span of an NYT journalist?
- Are specialist writers (1 section) more productive than generalists?
- How has author productivity changed over decades?

**Specific Analyses:**
- Identify "power authors" (high articles_per_year + long career)
- Find authors with the longest articles (longest_article_words)
- Track author debuts by decade

---

### 5. **Popularity & Virality Dashboard**

#### Insight: "What Goes Viral & When"

**Key Metrics:**
- Days until article becomes popular (days_since_published)
- Trending article characteristics (section, facets, keywords)
- Evergreen content (articles popular months/years after publication)

**Visualizations:**
```
📊 Histogram: Time to Popularity
   - X-axis: days_since_published (binned: 0-1, 1-7, 7-30, 30+)
   - Y-axis: count of popular articles
   - Source: fct_article_popularity
   - Shows if articles trend immediately vs. become popular later
   
📊 Bar Chart: Popular Sections
   - X-axis: section (from fct_article_popularity joined to stg_most_popular_articles)
   - Y-axis: count of appearances in most popular
   - Shows which sections produce the most viral content
   
📊 Line Chart: Popularity Decay Curve
   - X-axis: days_since_published
   - Y-axis: count of articles in most popular
   - Shows typical "half-life" of article popularity
   
📊 Table: Evergreen Articles
   - Columns: title, published_date, days_since_published, snapshot_date
   - Filter: days_since_published > 365
   - Source: fct_article_popularity with large days_since_published
```

**Questions Answered:**
- Do articles trend immediately or take time to gain traction?
- Which sections produce the most viral content?
- What's the typical "shelf life" of a popular article?
- Are there "evergreen" articles that remain popular for years?

**Advanced Analysis:**
- Correlate facet counts (description_facet_count, geo_facet_count) with virality
- Identify what makes an article "sticky" (long-lasting popularity)

---

### 6. **Historical Milestones Dashboard**

#### Insight: "170+ Years of News"

**Key Metrics:**
- Article volume by major historical events
- Coverage spikes during significant moments
- Decade-by-decade comparison

**Visualizations:**
```
📊 Annotated Timeline: Articles Published with Historical Context
   - X-axis: pub_year (1851-present)
   - Y-axis: total_articles (monthly or yearly)
   - Annotations: Major events (WWI, WWII, 9/11, COVID, etc.)
   - Shows coverage intensity during historical moments
   
📊 Bar Chart: Busiest News Years
   - X-axis: pub_year (top 20 years)
   - Y-axis: article_count
   - Source: agg_section_trends grouped by year
   
📊 Heatmap: Coverage Intensity by Month & Year
   - X-axis: month (1-12)
   - Y-axis: pub_year
   - Color: article_count
   - Shows seasonal patterns and historical anomalies
```

**Questions Answered:**
- When did NYT publish the most content?
- Can we see World Wars, elections, crises in the data?
- Are there seasonal publishing patterns?

**Specific Investigations:**
- 1929 (Great Depression)
- 1941-1945 (WWII)
- 1963 (JFK assassination)
- 2001 (9/11)
- 2008 (Financial Crisis)
- 2020 (COVID-19)
- 2024 (Election year)

---

### 7. **Content Quality & Richness Dashboard**

#### Insight: "The Depth of NYT Journalism"

**Key Metrics:**
- Keyword usage trends (avg_keywords_per_article)
- Author attribution (avg_authors_per_article)
- Multimedia integration trends
- Word count distribution

**Visualizations:**
```
📊 Multi-line Chart: Content Metadata Trends
   - X-axis: pub_month
   - Y-axis: avg_authors_per_article, avg_keywords_per_article
   - Source: agg_articles_by_month
   - Shows how article metadata has evolved
   
📊 Box Plot: Word Count Distribution by Section
   - X-axis: section_name (top 10 sections)
   - Y-axis: word_count
   - Source: fct_articles
   - Shows which sections write longer/shorter pieces
   
📊 Stacked Bar: Collaborative Articles Over Time
   - X-axis: pub_year
   - Y-axis: count of articles
   - Stack: author_count (1, 2, 3, 4+ authors)
   - Source: fct_articles
   - Shows trend toward multi-author journalism
```

**Questions Answered:**
- Are articles becoming more collaborative (multiple authors)?
- How has keyword tagging evolved?
- Which sections produce the longest investigative pieces?
- When did metadata become more structured?

---

### 8. **Real-Time Trending Dashboard**

#### Insight: "What's Hot Right Now"

**Key Metrics:**
- Current most popular articles
- Trending topics (from adx_keywords)
- Geographic trending (geo_facet)
- People in the news (per_facet)
- Organizations in the news (org_facet)

**Visualizations:**
```
📊 Card Grid: Today's Most Popular Articles
   - Layout: Card with title, section, days_since_published
   - Source: fct_article_popularity WHERE snapshot_date = CURRENT_DATE()
   - Limit: Top 20
   
📊 Tag Cloud: Trending Topics Today
   - Source: Exploded des_facet from fct_article_popularity (today)
   - Size: frequency in top articles
   
📊 Map: Geographic Focus
   - Source: Exploded geo_facet from fct_article_popularity (today)
   - Shows which locations are in the news
   
📊 Bar Chart: People in the News
   - X-axis: person name (from per_facet)
   - Y-axis: frequency in popular articles today
```

**Questions Answered:**
- What's trending on NYT right now?
- What topics, places, people are in focus today?
- How does today compare to historical trends?

---

### 9. **Comparative Analysis Dashboard**

#### Insight: "Then vs Now"

**Key Metrics:**
- Compare any two time periods
- Decade-over-decade changes

**Visualizations:**
```
📊 Side-by-Side Comparison: Decade Snapshot
   - Select two decades (e.g., 1960s vs 2020s)
   - Compare: Top sections, top keywords, avg word count, etc.
   
📊 Diverging Bar Chart: Section Growth/Decline
   - X-axis: yoy_change or decade-over-decade change
   - Y-axis: section_name
   - Shows relative growth (right) vs decline (left)
```

---

### 10. **Data Quality Dashboard**

#### Insight: "Metadata Completeness"

**Visualizations:**
```
📊 Line Chart: Metadata Completeness Over Time
   - X-axis: pub_year
   - Y-axis: % articles with authors, keywords, multimedia
   - Shows when structured metadata improved
   
📊 Stacked Bar: Articles by Material Type
   - X-axis: pub_year
   - Y-axis: count
   - Stack: type_of_material (News, Opinion, Review, etc.)
```

---

## Recommended Dashboard Structure

### Landing Page: "NYT at a Glance"
- Total articles (all time)
- Total authors
- Years of coverage
- Current most popular article
- Key trend sparklines (articles/month, keywords, etc.)

### Deep Dive Pages:
1. **Content Evolution** (agg_articles_by_month)
2. **Topics & Trends** (agg_keyword_trends)
3. **Sections & Coverage** (agg_section_trends)
4. **Authors & Contributors** (agg_author_performance)
5. **What's Trending** (fct_article_popularity + stg_most_popular_articles)
6. **Historical Moments** (fct_articles + annotations)

---

## Technical Recommendations

### BI Tool Suggestions:
1. **Looker** - Native BigQuery integration, advanced calculations
2. **Tableau** - Rich visualizations, good for racing bar charts
3. **Metabase** - Open source, simpler setup
4. **Streamlit** - Custom Python dashboard with full control

### Pre-Aggregation Tables to Create:
```sql
-- For performance, create additional rollups:

-- Daily snapshot summary
CREATE TABLE dbt_analytics.snapshot_daily_summary AS
SELECT 
  snapshot_date,
  COUNT(DISTINCT article_id) as unique_articles,
  AVG(days_since_published) as avg_age_of_popular,
  ARRAY_AGG(DISTINCT section ORDER BY section) as sections_represented
FROM fct_article_popularity
GROUP BY snapshot_date;

-- Keyword co-occurrence matrix (for network graphs)
CREATE TABLE dbt_analytics.keyword_cooccurrence AS
SELECT 
  k1.keyword_value as keyword_1,
  k2.keyword_value as keyword_2,
  COUNT(DISTINCT k1.article_id) as cooccurrence_count
FROM int_keywords_flattened k1
JOIN int_keywords_flattened k2 
  ON k1.article_id = k2.article_id 
  AND k1.keyword_value < k2.keyword_value
GROUP BY 1, 2;
```

---

## Next Steps for EDA

### 1. Profile the Data (SQL Queries)
```sql
-- Check data volume
SELECT 
  MIN(pub_date) as earliest_article,
  MAX(pub_date) as latest_article,
  COUNT(*) as total_articles,
  COUNT(DISTINCT section_name) as unique_sections
FROM times-api-ingest.dbt_core.fct_articles;

-- Top keywords all-time
SELECT 
  keyword_value,
  SUM(article_count) as total_articles
FROM times-api-ingest.dbt_analytics.agg_keyword_trends
GROUP BY 1
ORDER BY 2 DESC
LIMIT 50;

-- Productivity champions
SELECT 
  author_full_name,
  total_articles,
  articles_per_year,
  first_year,
  last_year
FROM times-api-ingest.dbt_analytics.agg_author_performance
ORDER BY total_articles DESC
LIMIT 50;

-- Trending topics (last year)
SELECT 
  keyword_value,
  article_count,
  yoy_change_pct
FROM times-api-ingest.dbt_analytics.agg_keyword_trends
WHERE pub_year = EXTRACT(YEAR FROM CURRENT_DATE()) - 1
ORDER BY yoy_change_pct DESC
LIMIT 30;
```

### 2. Sample the Popular Articles
```sql
-- Recent viral articles
SELECT 
  p.title,
  p.section,
  p.published_date,
  p.snapshot_date,
  p.days_since_published,
  p.url
FROM times-api-ingest.dbt_core.fct_article_popularity p
WHERE p.snapshot_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
ORDER BY p.snapshot_date DESC, p.days_since_published ASC
LIMIT 100;
```

### 3. Identify Anomalies
```sql
-- Busiest publishing months ever
SELECT 
  pub_month,
  total_articles,
  avg_word_count
FROM times-api-ingest.dbt_analytics.agg_articles_by_month
ORDER BY total_articles DESC
LIMIT 20;

-- Keywords that spiked dramatically
SELECT 
  keyword_value,
  pub_year,
  article_count,
  prior_year_count,
  yoy_change_pct
FROM times-api-ingest.dbt_analytics.agg_keyword_trends
WHERE yoy_change_pct > 500  -- 5x growth
  AND article_count > 100   -- significant volume
ORDER BY yoy_change_pct DESC;
```

---

## Key Insights to Investigate

### Content Patterns:
1. **Word count deflation?** - Are modern articles shorter due to digital reading habits?
2. **Multimedia adoption curve** - When did images/video become standard?
3. **Collaboration trends** - Are more articles multi-author now?

### Editorial Patterns:
4. **Section evolution** - Did "Technology" section grow post-2000?
5. **Opinion vs News ratio** - Has opinion content increased?
6. **International vs Domestic** - Coverage balance over time

### Popularity Patterns:
7. **Virality formula** - Common traits of most popular articles
8. **Shelf life** - Do investigative pieces stay popular longer?
9. **Section popularity bias** - Are certain sections over-represented in "most popular"?

### Historical Patterns:
10. **War coverage** - Spikes during WWI, WWII, Vietnam, Iraq, Ukraine
11. **Election cycles** - 4-year patterns in political keywords
12. **Technology evolution** - "Internet", "iPhone", "AI" keyword emergence
13. **Climate coverage** - Growth of climate/environment topics

---

## Dashboard Wireframe Example

```
┌─────────────────────────────────────────────────┐
│  NYT ANALYTICS                    [Date Picker] │
├─────────────────────────────────────────────────┤
│  ┌─────────┐  ┌─────────┐  ┌─────────┐         │
│  │ 2.5M    │  │ 12,400  │  │  170    │         │
│  │Articles │  │ Authors │  │ Years   │         │
│  └─────────┘  └─────────┘  └─────────┘         │
├─────────────────────────────────────────────────┤
│  📊 Articles Published Over Time                │
│  [Line chart: pub_month vs total_articles]     │
├─────────────────────────────────────────────────┤
│  📊 Top Trending Keywords    📊 Popular Today   │
│  [Bump chart]                [Card grid]        │
├─────────────────────────────────────────────────┤
│  📊 Section Composition      📊 Author Leaders  │
│  [Stacked area]              [Table]            │
└─────────────────────────────────────────────────┘
```

---

## Conclusion

The NYT dbt models provide a rich foundation for creating insightful dashboards covering:
- **Historical analysis** (170+ years of content evolution)
- **Topic trends** (what's covered and how it changes)
- **Author analytics** (who writes, how much, on what)
- **Popularity tracking** (what goes viral and why)
- **Real-time insights** (today's trending content)

The combination of historical depth (archive) and real-time tracking (most popular) creates unique opportunities for comparative analysis and trend identification.

**Next Action:** Run the SQL queries in the "Next Steps for EDA" section to profile the data and validate these dashboard concepts.
