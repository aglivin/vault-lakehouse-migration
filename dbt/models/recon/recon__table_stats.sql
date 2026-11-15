-- noqa: disable=all
{% set tables = [
    {'model': 'hub_customer', 'key': 'customer_hk'},
    {'model': 'hub_contract', 'key': 'contract_hk'},
    {'model': 'hub_invoice', 'key': 'invoice_hk'},
    {'model': 'hub_meter', 'key': 'meter_hk'},
    {'model': 'hub_tariff', 'key': 'tariff_hk'},
    {'model': 'link_customer_contract', 'key': 'customer_contract_hk'},
    {'model': 'link_contract_meter', 'key': 'contract_meter_hk'},
    {'model': 'link_contract_invoice', 'key': 'contract_invoice_hk'},
    {'model': 'link_invoice_tariff', 'key': 'invoice_tariff_hk'},
    {'model': 'sal_customer', 'key': 'sal_customer_hk'},
    {'model': 'sal_contract', 'key': 'sal_contract_hk'},
    {'model': 'sal_invoice', 'key': 'sal_invoice_hk'},
    {'model': 'sal_meter', 'key': 'sal_meter_hk'},
    {'model': 'sal_tariff', 'key': 'sal_tariff_hk'},
    {'model': 'sat_customer_details_crm_v1', 'key': 'customer_hk', 'ldts': 'load_datetime'},
    {'model': 'sat_customer_details_crm_v2', 'key': 'customer_hk', 'ldts': 'load_datetime'},
    {'model': 'sat_customer_phone_ma', 'key': 'customer_hk', 'ldts': 'load_datetime'},
    {'model': 'sat_contract_details_billing_v1', 'key': 'contract_hk', 'ldts': 'load_datetime'},
    {'model': 'sat_contract_details_billing_v2', 'key': 'contract_hk', 'ldts': 'load_datetime'},
    {'model': 'sat_invoice_details_billing_v1', 'key': 'invoice_hk', 'ldts': 'load_datetime'},
    {'model': 'sat_invoice_details_billing_v2', 'key': 'invoice_hk', 'ldts': 'load_datetime'},
    {'model': 'sat_invoice_line_billing_v1', 'key': 'invoice_hk', 'ldts': 'load_datetime', 'measures': ['kwh', 'net_amount', 'tax_amount']},
    {'model': 'sat_invoice_line_billing_v2', 'key': 'invoice_hk', 'ldts': 'load_datetime', 'measures': ['quantity_kwh', 'amount_net', 'vat_amount']},
    {'model': 'sat_tariff_details_billing_v1', 'key': 'tariff_hk', 'ldts': 'load_datetime', 'measures': ['price_per_kwh', 'base_fee_month']},
    {'model': 'sat_tariff_details_billing_v2', 'key': 'tariff_hk', 'ldts': 'load_datetime', 'measures': ['unit_price_kwh', 'monthly_fee']},
    {'model': 'eff_sat_customer_contract', 'key': 'customer_contract_hk', 'ldts': 'load_datetime'},
    {'model': 'sts_contract', 'key': 'contract_hk', 'ldts': 'load_datetime'},
    {'model': 'bv_customer_master', 'key': 'master_customer_hk'},
    {'model': 'bv_contract_master', 'key': 'master_contract_hk'},
    {'model': 'bv_invoice_master', 'key': 'master_invoice_hk'},
    {'model': 'bv_meter_master', 'key': 'master_meter_hk'},
    {'model': 'bv_tariff_master', 'key': 'master_tariff_hk'},
    {'model': 'fct_invoice_line', 'measures': ['kwh', 'net_amount', 'tax_amount']},
    {'model': 'dim_tariff', 'measures': ['price_per_kwh', 'base_fee_month']},
    {'model': 'billing__revenue_by_tariff_month', 'measures': ['invoice_count', 'kwh', 'net_amount', 'vat_amount']},
] %}
{% set string_type = dbt.type_string() %}

{% for table in tables %}
    {% set hex = hex_key(table.key) if table.key else none %}
    select
        '{{ table.model }}' as table_name,
        count(*) as row_count,
        {% if hex %}
            count(distinct {{ hex }}) as distinct_keys,
            min({{ hex }}) as key_min,
            max({{ hex }}) as key_max,
            cast(sum({{ hex_prefix_number(hex) }}) as {{ string_type }}) as key_checksum,
        {% else %}
            cast(null as bigint) as distinct_keys,
            cast(null as {{ string_type }}) as key_min,
            cast(null as {{ string_type }}) as key_max,
            cast(null as {{ string_type }}) as key_checksum,
        {% endif %}
        {% if table.measures %}
            concat(
                {% for measure in table.measures %}
                    '{{ measure }}=',
                    cast(cast(coalesce(sum(cast({{ measure }} as decimal(38, 4))), 0) as decimal(38, 2)) as {{ string_type }})
                    {%- if not loop.last %}, ';',{% endif %}
                {% endfor %}
            ) as measure_sums,
        {% else %}
            cast(null as {{ string_type }}) as measure_sums,
        {% endif %}
        {% if table.ldts %}
            cast(cast(min({{ table.ldts }}) as date) as {{ string_type }}) as min_load_date,
            cast(cast(max({{ table.ldts }}) as date) as {{ string_type }}) as max_load_date
        {% else %}
            cast(null as {{ string_type }}) as min_load_date,
            cast(null as {{ string_type }}) as max_load_date
        {% endif %}
    from {{ ref(table.model) }}
    {% if not loop.last %}union all{% endif %}
{% endfor %}
