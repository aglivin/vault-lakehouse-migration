{% macro drop_pr_schemas() %}
    {% set prefix = target.schema | lower %}
    {% if not prefix.startswith('ci_pr_') %}
        {{ exceptions.raise_compiler_error('drop_pr_schemas runs only on a ci_pr_<number> schema, got ' ~ target.schema) }}
    {% endif %}
    {% set schemas = run_query(
        "select schema_name from " ~ target.database ~ ".information_schema.schemata"
        ~ " where lower(schema_name) like '" ~ prefix ~ "%'"
    ).columns[0].values() %}
    {% for schema in schemas if schema | lower == prefix or (schema | lower).startswith(prefix ~ '_') %}
        {% do log('dropping schema ' ~ schema, info=true) %}
        {% do adapter.drop_schema(api.Relation.create(database=target.database, schema=schema)) %}
    {% endfor %}
{% endmacro %}
