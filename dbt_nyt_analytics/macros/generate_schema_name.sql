{% macro generate_schema_name(custom_schema_name, node) -%}
    {#
    Custom schema naming to support dev/prod separation.
    
    Behavior:
    - Dev target: Prefixes schemas with "dev_" (e.g., dev_dbt_staging)
    - Prod target: Uses schema name as-is (e.g., dbt_staging)
    
    This allows dev and prod to write to different datasets automatically
    based on the --target flag.
    #}
    
    {%- set default_schema = target.schema -%}
    
    {%- if custom_schema_name is none -%}
        {#- No custom schema specified, use default from profile -#}
        {{ default_schema }}
    
    {%- elif target.name == 'prod' -%}
        {#- Production: use custom schema as-is -#}
        {{ custom_schema_name | trim }}
    
    {%- else -%}
        {#- Dev/other targets: prefix with "dev_" -#}
        dev_{{ custom_schema_name | trim }}
    
    {%- endif -%}

{%- endmacro %}
