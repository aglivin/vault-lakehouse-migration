{% macro skip_loaded_load_dates(src_pk, src_ldts='LOAD_DATETIME') %}
    {% if is_incremental() %}
        with candidate as (
            {{ caller() }}
        )

        select candidate.*
        from candidate
        where not exists (
            select 1
            from {{ this }} as loaded
            where
                loaded.{{ src_pk }} = candidate.{{ src_pk }}
                and loaded.{{ src_ldts }} >= candidate.{{ src_ldts }}
        )
    {% else %}
        {{ caller() }}
    {% endif %}
{% endmacro %}
