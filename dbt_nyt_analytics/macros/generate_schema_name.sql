{% macro generate_schema_name(custom_schema_name, node) -%}
    {#
    Custom schema naming to support dev/prod separation.

    Behavior:
    - CI target: single BigQuery dataset per PR (dbt_pr_<number>), set via --vars
    - Dev target: Prefixes schemas with "dev_" (e.g., dev_dbt_staging)
    - Prod target: Uses schema name as-is (e.g., dbt_staging)
    #}

    {%- if target.name == 'ci' -%}
        dbt_pr_{{ var('pr_number') }}

    {%- elif custom_schema_name is none -%}
        {{ target.schema }}

    {%- elif target.name == 'prod' -%}
        {{ custom_schema_name | trim }}

    {%- else -%}
        dev_{{ custom_schema_name | trim }}

    {%- endif -%}

{%- endmacro %}
