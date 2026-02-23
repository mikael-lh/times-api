with keywords as (
    select * from {{ ref('int_keywords_flattened') }}
),

yearly_keyword_stats as (
    select
        keyword_name,
        keyword_value,
        pub_year,
        
        count(distinct article_id) as article_count,
        count(*) as keyword_occurrences
        
    from keywords
    where keyword_value is not null
        and trim(keyword_value) != ''
    group by 1, 2, 3
),

with_rankings as (
    select
        *,
        
        -- Rank within year
        row_number() over (
            partition by pub_year 
            order by article_count desc
        ) as rank_in_year,
        
        -- Prior year metrics
        lag(article_count) over (
            partition by keyword_name, keyword_value 
            order by pub_year
        ) as prior_year_count,
        
        lag(row_number() over (
            partition by pub_year 
            order by article_count desc
        )) over (
            partition by keyword_name, keyword_value 
            order by pub_year
        ) as prior_year_rank
        
    from yearly_keyword_stats
),

final as (
    select
        keyword_name,
        keyword_value,
        pub_year,
        
        article_count,
        keyword_occurrences,
        rank_in_year,
        
        prior_year_count,
        article_count - coalesce(prior_year_count, 0) as yoy_change,
        case 
            when prior_year_count > 0 
            then round(100.0 * (article_count - prior_year_count) / prior_year_count, 1)
            else null 
        end as yoy_change_pct,
        
        prior_year_rank,
        coalesce(prior_year_rank, 0) - rank_in_year as rank_change
        
    from with_rankings
)

select * from final
order by pub_year desc, article_count desc
