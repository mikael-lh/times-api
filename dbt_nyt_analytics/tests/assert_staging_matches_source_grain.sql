-- Test that staging maintains the same grain as source
-- Compares row counts between source and staging

with source_count as (
    select count(*) as cnt from {{ source('nyt_raw', 'archive_articles') }}
),

staging_count as (
    select count(*) as cnt from {{ ref('stg_archive_articles') }}
)

select 
    source_count.cnt as source_rows,
    staging_count.cnt as staging_rows,
    source_count.cnt - staging_count.cnt as difference
from source_count, staging_count
where source_count.cnt != staging_count.cnt
