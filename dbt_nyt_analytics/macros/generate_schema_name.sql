{% macro generate_schema_name(custom_schema_name, node) -%}
    {#
    Custom schema naming to support dev/prod separation.

    Behavior:
    - CI target: ci_dbt when pr_number is unset; ci_dbt_<number> when --vars passes pr_number
    - Dev target: Prefixes schemas with "dev_" (e.g., dev_dbt_staging)
    - Prod target: Uses schema name as-is (e.g., dbt_staging)
    #}

    {%- if target.name == 'ci' -%}
        {%- set pr_number = var('pr_number', '') | string | trim -%}
        {%- if pr_number == '' -%}
            ci_dbt
        {%- else -%}
            ci_dbt_{{ pr_number }}
        {%- endif -%}

    {%- elif custom_schema_name is none -%}
        {{ target.schema }}

    {%- elif target.name == 'prod' -%}
        {{ custom_schema_name | trim }}

    {%- else -%}
        dev_{{ custom_schema_name | trim }}

    {%- endif -%}

{%- endmacro %}
