{% macro stage_raw(system, entity, hashed_columns) %}
    {% set source_model = {system: system ~ '__' ~ entity} %}
    {% set derived_columns = {'LOAD_DATETIME': '_load_date', 'RECORD_SOURCE': '_record_source'} %}
    with staged as (
        {{ automate_dv.stage(
            include_source_columns=true,
            source_model=source_model,
            derived_columns=derived_columns,
            hashed_columns=hashed_columns
        ) }}
    )

    select *
    from staged
    where 1 = 1
        {% if var('load_date') %}
            and load_datetime = cast('{{ var("load_date") }}' as date)
        {% endif %}
{% endmacro %}
