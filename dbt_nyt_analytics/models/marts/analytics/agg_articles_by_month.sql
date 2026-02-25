with articles as (
    select * from {{ ref('fct_articles') }}
),

monthly_stats as (
    select
        date_trunc(pub_date, month) as pub_month,
        
        -- Counts
        count(*) as total_articles,
        
        -- Word count metrics
        avg(word_count) as avg_word_count,
        sum(word_count) as total_word_count,
        max(word_count) as max_word_count,
        
        -- Content richness
        countif(has_authors) as articles_with_authors,
        countif(has_keywords) as articles_with_keywords,
        countif(has_multimedia) as articles_with_multimedia,
        
        -- Author metrics
        avg(author_count) as avg_authors_per_article,
        sum(author_count) as total_author_appearances,
        
        -- Keyword metrics
        avg(keyword_count) as avg_keywords_per_article,
        sum(keyword_count) as total_keywords,
        
        -- Section diversity
        count(distinct section_name) as unique_sections,
        count(distinct news_desk) as unique_news_desks,
        
        -- Material types
        count(distinct type_of_material) as unique_material_types
        
    from articles
    group by 1
),

final as (
    select
        pub_month,
        total_articles,
        
        round(avg_word_count, 0) as avg_word_count,
        total_word_count,
        max_word_count,
        
        articles_with_authors,
        articles_with_keywords,
        articles_with_multimedia,
        
        round(avg_authors_per_article, 2) as avg_authors_per_article,
        round(avg_keywords_per_article, 2) as avg_keywords_per_article,
        
        unique_sections,
        unique_news_desks,
        unique_material_types,
        
        -- Percentages
        round(100.0 * articles_with_authors / nullif(total_articles, 0), 1) as pct_with_authors,
        round(100.0 * articles_with_keywords / nullif(total_articles, 0), 1) as pct_with_keywords,
        round(100.0 * articles_with_multimedia / nullif(total_articles, 0), 1) as pct_with_multimedia
    
    from monthly_stats
    order by pub_month
)

select * from final
