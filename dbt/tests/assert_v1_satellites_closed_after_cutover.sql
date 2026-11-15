{% set v1_satellites = [
    'sat_customer_details_crm_v1',
    'sat_contract_details_billing_v1',
    'sat_invoice_details_billing_v1',
    'sat_invoice_line_billing_v1',
    'sat_tariff_details_billing_v1',
    'sat_customer_phone_ma'
] %}

{% for satellite in v1_satellites %}
    select
        '{{ satellite }}' as satellite,
        max(load_datetime) as last_load_datetime
    from {{ ref(satellite) }}
    having max(load_datetime) >= cast('{{ var("cutover_date") }}' as date)
    {% if not loop.last %}
        union all
    {% endif %}
{% endfor %}
