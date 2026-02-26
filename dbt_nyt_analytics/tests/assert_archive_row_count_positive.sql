-- Test that archive source has data loaded
-- This will fail if the source table is empty

with row_count as (
    select count(*) as total_rows
    from {{ source('nyt_raw', 'archive_articles') }}
)

select *
from row_count
where total_rows = 0
