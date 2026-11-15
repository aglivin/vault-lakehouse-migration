{% macro month_trunc(date_expression) %}
    {{ return(adapter.dispatch('month_trunc', 'vdwh')(date_expression)) }}
{% endmacro %}

{% macro default__month_trunc(date_expression) %}
    cast(date_trunc('month', {{ date_expression }}) as date)
{% endmacro %}

{% macro snowflake__month_trunc(date_expression) %}
    date_trunc('month', {{ date_expression }})
{% endmacro %}

{% macro databricks__month_trunc(date_expression) %}
    trunc({{ date_expression }}, 'MM')
{% endmacro %}
