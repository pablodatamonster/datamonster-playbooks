-- Where each model is built.
-- prod target: exactly the folder's schema, such as STAGING or MARTS.
-- dev target:  the same name with DEV_ in front (DEV_STAGING, DEV_MARTS), so
--              trying things out never touches what dashboards read.
-- dbt's default would give names like STAGING_STAGING, which is why this exists.

{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set schema_name = (custom_schema_name or target.schema) | trim | upper -%}
    {%- if target.name == 'prod' -%}
        {{ schema_name }}
    {%- else -%}
        DEV_{{ schema_name }}
    {%- endif -%}
{%- endmacro %}
