-- Test that archive source has data loaded
-- This will fail if the source table is empty

select 1
from {{ source('nyt_raw', 'archive_articles') }}
having count(*) = 0
