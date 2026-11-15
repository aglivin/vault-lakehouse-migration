{% macro hex_key(column) %}
    {{ return(adapter.dispatch('hex_key', 'vdwh')(column)) }}
{% endmacro %}

{% macro default__hex_key(column) %}
    upper(cast({{ column }} as {{ dbt.type_string() }}))
{% endmacro %}

{% macro snowflake__hex_key(column) %}
    upper(to_varchar({{ column }}, 'HEX'))
{% endmacro %}

{% macro hex_prefix_number(hex_expression) %}
    {{ return(adapter.dispatch('hex_prefix_number', 'vdwh')(hex_expression)) }}
{% endmacro %}

{% macro default__hex_prefix_number(hex_expression) %}
    cast(conv(substr({{ hex_expression }}, 1, 8), 16, 10) as bigint)
{% endmacro %}

{% macro snowflake__hex_prefix_number(hex_expression) %}
    to_number(substr({{ hex_expression }}, 1, 8), 'XXXXXXXX')
{% endmacro %}
