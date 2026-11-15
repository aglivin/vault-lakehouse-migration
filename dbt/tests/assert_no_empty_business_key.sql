{% set hubs = {
    'hub_customer': 'customer_no',
    'hub_contract': 'contract_no',
    'hub_meter': 'meter_no',
    'hub_invoice': 'invoice_no',
    'hub_tariff': 'tariff_code'
} %}

{% for hub, key in hubs.items() %}
    select
        '{{ hub }}' as hub_name,
        {{ key }} as business_key
    from {{ ref(hub) }}
    where nullif(trim({{ key }}), '') is null
    {% if not loop.last %}
        union all
    {% endif %}
{% endfor %}
