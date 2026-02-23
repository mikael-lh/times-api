with keywords as (
    select distinct
        keyword_name,
        keyword_value
    from {{ ref('int_keywords_flattened') }}
    where keyword_value is not null
        and trim(keyword_value) != ''
),

with_key as (
    select
        {{ dbt_utils.generate_surrogate_key(['keyword_name', 'keyword_value']) }} as keyword_key,
        keyword_name,
        keyword_value
    from keywords
)

select * from with_key
