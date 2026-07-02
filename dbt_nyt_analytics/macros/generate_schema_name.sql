{% macro generate_schema_name(custom_schema_name, node) -%}
    {#
    prod: custom schema as-is (e.g. dbt_staging)
    dev: dev_ prefix (e.g. dev_dbt_staging)
    ci: profile dataset (ci_dbt) when pr_number is empty; ci_dbt_<n> when set via --vars
    no +schema: custom_schema_name is none — use profile default dataset (target.schema)
    #}

    {%- if target.name == 'ci' -%}
        {%- set pr = var('pr_number') | string | trim -%}
        {{ target.schema if pr == '' else 'ci_dbt_' ~ pr }}

    {%- elif custom_schema_name is none -%}
        {{ target.schema }}

    {%- elif target.name == 'prod' -%}
        {{ custom_schema_name | trim }}

    {%- else -%}
        dev_{{ custom_schema_name | trim }}

    {%- endif -%}

{%- endmacro %}
