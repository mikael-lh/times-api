with author_articles as (
    select
        af.author_full_name,
        af.firstname,
        af.lastname,
        af.article_id,
        af.pub_date,
        af.pub_year,
        af.section_name,
        fa.word_count,
        fa.keyword_count
    from {{ ref('int_authors_flattened') }} af
    inner join {{ ref('fct_articles') }} fa on af.article_id = fa.article_id
),

author_stats as (
    select
        author_full_name,
        firstname,
        lastname,
        
        -- Article counts
        count(distinct article_id) as total_articles,
        
        -- Date range
        min(pub_date) as first_article_date,
        max(pub_date) as last_article_date,
        date_diff(max(pub_date), min(pub_date), day) as career_span_days,
        
        -- Years active
        count(distinct pub_year) as years_active,
        min(pub_year) as first_year,
        max(pub_year) as last_year,
        
        -- Content metrics
        avg(word_count) as avg_word_count,
        sum(word_count) as total_words_written,
        max(word_count) as longest_article_words,
        
        -- Topic diversity
        count(distinct section_name) as sections_written_for,
        avg(keyword_count) as avg_keywords_per_article
        
    from author_articles
    group by 1, 2, 3
)

select
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
    
    round(avg_word_count, 0) as avg_word_count,
    total_words_written,
    longest_article_words,
    
    sections_written_for,
    round(avg_keywords_per_article, 1) as avg_keywords_per_article,
    
    -- Productivity metric
    round(total_articles / nullif(years_active, 0), 1) as articles_per_year

from author_stats
order by total_articles desc
