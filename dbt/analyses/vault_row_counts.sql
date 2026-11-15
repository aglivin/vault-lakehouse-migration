{% set vault_tables = {
    'hub': ['hub_customer', 'hub_contract', 'hub_meter', 'hub_invoice', 'hub_tariff'],
    'link': [
        'link_customer_contract', 'link_contract_meter', 'link_contract_invoice', 'link_invoice_tariff',
        'sal_customer', 'sal_contract', 'sal_invoice', 'sal_tariff', 'sal_meter'
    ],
    'nh_link': ['nhl_payment_billing_v1', 'nhl_payment_billing_v2'],
    'sat': [
        'sat_customer_details_crm_v1', 'sat_customer_details_crm_v2',
        'sat_contract_details_billing_v1', 'sat_contract_details_billing_v2',
        'sat_invoice_details_billing_v1', 'sat_invoice_details_billing_v2',
        'sat_tariff_details_billing_v1', 'sat_tariff_details_billing_v2'
    ],
    'ma_sat': ['sat_customer_phone_ma', 'sat_invoice_line_billing_v1', 'sat_invoice_line_billing_v2'],
    'eff_sat': ['eff_sat_customer_contract'],
    'sts': ['sts_contract']
} %}

{% for table_type, table_names in vault_tables.items() %}
    {% for table_name in table_names %}
        select
            '{{ table_type }}' as table_type,
            '{{ table_name }}' as table_name,
            count(*) as row_count
        from {{ ref(table_name) }}
        {% if not loop.last %}union all{% endif %}
    {% endfor %}
    {% if not loop.last %}union all{% endif %}
{% endfor %}
order by table_type, table_name
