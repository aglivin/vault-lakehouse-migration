{% macro load_raw(load_date) %}
    {% do modules.datetime.date.fromisoformat(load_date | string) %}
    {% set database = target.database %}
    {% for name, columns in var('raw_entities').items() %}
        {% set system, entity = name.split('__') %}
        {% set table = database ~ '.raw.' ~ name %}
        {% do run_query('delete from ' ~ table ~ " where _load_date = '" ~ load_date ~ "'") %}
        {% do run_query(vdwh.copy_into_raw(database, table, columns, system, entity, load_date)) %}
    {% endfor %}
{% endmacro %}

{% macro copy_into_raw(database, table, columns, system, entity, load_date) %}
    {{ return(adapter.dispatch('copy_into_raw', 'vdwh')(database, table, columns, system, entity, load_date)) }}
{% endmacro %}

{% macro snowflake__copy_into_raw(database, table, columns, system, entity, load_date) %}
    {% set fields = [] %}
    {% for column in columns %}
        {% do fields.append('$' ~ loop.index) %}
    {% endfor %}
    copy into {{ table }}
    from (
        select
            {{ fields | join(', ') }},
            '{{ load_date }}'::date,
            '{{ system }}'
        from @{{ database }}.raw.landing/{{ system }}/{{ entity }}/
    )
    files = ('{{ load_date }}.csv')
    force = true
{% endmacro %}

{% macro databricks__copy_into_raw(database, table, columns, system, entity, load_date) %}
    copy into {{ table }}
    from (
        select
            {{ columns | join(', ') }},
            cast('{{ load_date }}' as date) as _load_date,
            '{{ system }}' as _record_source
        from '/Volumes/{{ database }}/raw/landing/{{ system }}/{{ entity }}/'
    )
    fileformat = csv
    files = ('{{ load_date }}.csv')
    format_options ('header' = 'true', 'escape' = '"')
    copy_options ('force' = 'true')
{% endmacro %}
