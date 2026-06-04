{# SQLFluff-only stubs (loaded after project macros to override for lint/fix). #}

{% macro is_incremental() %}
    {{ return(false) }}
{% endmacro %}

{% macro ref(model_name) %}
    {{ model_name }}
{% endmacro %}

{% macro source(source_name, table_name) %}
    {{ source_name }}__{{ table_name }}
{% endmacro %}

{% macro generate_surrogate_key(field_list) %}
    '_surrogate_key_'
{% endmacro %}
