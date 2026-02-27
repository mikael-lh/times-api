{% macro get_incremental_filter(date_column, lookback_days=None) %}
    {#
        Returns an incremental filter clause for date-based incremental models.
        
        Args:
            date_column: The date column to filter on
            lookback_days: (unused) retained for backwards compatibility
        
        Behavior:
            - On the first run (non-incremental), the model loads all history.
            - On incremental runs, only rows with {{ date_column }} strictly
              greater than the current max {{ date_column }} in {{ this }} are processed
              (append-only incremental loading).
        
        Usage:
            {% if is_incremental() %}
                where {{ get_incremental_filter('pub_date') }}
            {% endif %}
    #}
    
    {{ date_column }} > (
        select max({{ date_column }})
        from {{ this }}
    )
{% endmacro %}
