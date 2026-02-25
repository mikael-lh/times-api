with articles as (
    select * from {{ ref('fct_articles') }}
),

yearly_totals as (
    select
        pub_year,
        count(*) as year_total
    from articles
    group by 1
),

section_yearly as (
    select
        a.section_name,
        a.news_desk,
        a.pub_year,
        
        count(*) as article_count,
        avg(a.word_count) as avg_word_count,
        sum(a.word_count) as total_word_count,
        
        countif(a.has_authors) as articles_with_authors,
        countif(a.has_keywords) as articles_with_keywords,
        
        avg(a.author_count) as avg_authors,
        avg(a.keyword_count) as avg_keywords
        
    from articles a
    group by 1, 2, 3
),

with_percentages as (
    select
        sy.*,
        yt.year_total,
        round(100.0 * sy.article_count / nullif(yt.year_total, 0), 2) as pct_of_year_total,
        
        -- Year-over-year change
        lag(sy.article_count) over (
            partition by sy.section_name, sy.news_desk 
            order by sy.pub_year
        ) as prior_year_count
        
    from section_yearly sy
    left join yearly_totals yt on sy.pub_year = yt.pub_year
),

final as (
    select
        section_name,
        news_desk,
        pub_year,
        
        article_count,
        year_total,
        pct_of_year_total,
        
        round(avg_word_count, 0) as avg_word_count,
        total_word_count,
        
        articles_with_authors,
        articles_with_keywords,
        
        round(avg_authors, 2) as avg_authors,
        round(avg_keywords, 2) as avg_keywords,
        
        prior_year_count,
        article_count - coalesce(prior_year_count, 0) as yoy_change,
        case 
            when prior_year_count > 0 
            then round(100.0 * (article_count - prior_year_count) / prior_year_count, 1)
            else null 
        end as yoy_change_pct
    
    from with_percentages
    order by pub_year, article_count desc
)

select * from final
