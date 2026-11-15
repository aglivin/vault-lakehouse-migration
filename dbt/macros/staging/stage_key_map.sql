{% macro stage_key_map(system, entities) %}
    {% set derived_columns = {} %}
    {% set hashed_columns = {} %}
    {% for entity in entities %}
        {% set prefix = entity | upper %}
        {% do derived_columns.update({
            prefix ~ '_V1_KEY': "case when entity = '" ~ entity ~ "' then v1_key end",
            prefix ~ '_V2_KEY': "case when entity = '" ~ entity ~ "' then v2_key end"
        }) %}
        {% do hashed_columns.update({
            prefix ~ '_HK': prefix ~ '_V1_KEY',
            prefix ~ '_V2_HK': prefix ~ '_V2_KEY',
            'SAL_' ~ prefix ~ '_HK': [prefix ~ '_V1_KEY', prefix ~ '_V2_KEY']
        }) %}
    {% endfor %}
    {{ vdwh.stage_raw(system, 'key_map', hashed_columns, derived_columns) }}
{% endmacro %}
