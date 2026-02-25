{% macro get_incremental_filter(date_column, lookback_days=None) %}
    {#
        Returns an incremental filter clause for date-based incremental models.
        
        Args:
            date_column: The date column to filter on
            lookback_days: Number of days to look back (defaults to var('incremental_lookback_days'))
        
        Usage:
            {% if is_incremental() %}
                where {{ get_incremental_filter('pub_date') }}
            {% endif %}
    #}
    
    {% set days = lookback_days or var('incremental_lookback_days', 3) %}
    
    {{ date_column }} >= date_sub(
        (select max({{ date_column }}) from {{ this }}),
        interval {{ days }} day
    )
{% endmacro %}
