{% macro create_raw_tables() %}
    {% set database = target.database %}
    {% do run_query('create schema if not exists ' ~ database ~ '.raw') %}
    {% do run_query(vdwh.create_landing_area(database)) %}
    {% for name, columns in var('raw_entities').items() %}
        {% set column_list = [] %}
        {% for column in columns %}
            {% do column_list.append(column ~ ' string') %}
        {% endfor %}
        {% do column_list.append('_load_date date') %}
        {% do column_list.append('_record_source string') %}
        {% do run_query('create table if not exists ' ~ database ~ '.raw.' ~ name ~ ' (' ~ column_list | join(', ') ~ ')') %}
    {% endfor %}
{% endmacro %}

{% macro create_landing_area(database) %}
    {{ return(adapter.dispatch('create_landing_area', 'vdwh')(database)) }}
{% endmacro %}

{% macro snowflake__create_landing_area(database) %}
    create stage if not exists {{ database }}.raw.landing
    file_format = (type = csv skip_header = 1 field_optionally_enclosed_by = '"')
{% endmacro %}

{% macro databricks__create_landing_area(database) %}
    create volume if not exists {{ database }}.raw.landing
{% endmacro %}
