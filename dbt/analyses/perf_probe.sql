{% set invoice_date = var("perf_invoice_date", none) %}
{% set tariff_code = var("perf_tariff_code", none) %}

select
    '{{ var("perf_label", "probe_1") }}' as perf_probe,
    count(*) as line_count,
    sum(net_amount) as net_total
from {{ ref('fct_invoice_line') }}
where
    1 = 1
    {% if invoice_date is not none %}
        and invoice_date = cast('{{ invoice_date }}' as date)
    {% endif %}
    {% if tariff_code is not none %}
        and tariff_code = '{{ tariff_code }}'
    {% endif %}
