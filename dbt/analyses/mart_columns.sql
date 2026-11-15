{% set marts = [
    ref('fct_invoice_line'),
    ref('billing__revenue_by_tariff_month')
] %}

select
    ordinal_position,
    lower(table_name) as table_name,
    lower(column_name) as column_name,
    upper(data_type) as data_type
from {{ marts[0].database }}.information_schema.columns
where
    upper(table_schema) = upper('{{ marts[0].schema }}')
    and upper(table_name) in (
        {% for mart in marts %}
            upper('{{ mart.identifier }}'){{ ',' if not loop.last }}
        {% endfor %}
    )
order by table_name, ordinal_position
