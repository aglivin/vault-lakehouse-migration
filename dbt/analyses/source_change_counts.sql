{% set entities = {
    'customer': {'key_map': 'crm_v2', 'v1': ['crm_v1', 'crm_v1__customers', 'customer_no'], 'v2': ['crm_v2', 'crm_v2__accounts', 'account_uuid']},
    'contract': {'key_map': 'billing_v2', 'v1': ['billing_v1', 'billing_v1__contracts', 'contract_no'], 'v2': ['billing_v2', 'billing_v2__agreements', 'agreement_id']},
    'invoice': {'key_map': 'billing_v2', 'v1': ['billing_v1', 'billing_v1__invoices', 'invoice_no'], 'v2': ['billing_v2', 'billing_v2__documents', 'document_id']},
    'tariff': {'key_map': 'billing_v2', 'v1': ['billing_v1', 'billing_v1__tariffs', 'tariff_code'], 'v2': ['billing_v2', 'billing_v2__products', 'product_code']},
    'meter': {'key_map': 'billing_v2', 'v1': ['billing_v1', 'billing_v1__meters', 'meter_no'], 'v2': ['billing_v2', 'billing_v2__meter_points', 'meter_point_id']}
} %}

{% set v1_satellites = [
    'sat_customer_details_crm_v1',
    'sat_contract_details_billing_v1',
    'sat_invoice_details_billing_v1',
    'sat_invoice_line_billing_v1',
    'sat_tariff_details_billing_v1'
] %}

with entity_counts as (
    {% for entity, spec in entities.items() %}
        select
            '{{ entity }}' as object_name,
            (
                select count(*)
                from {{ source(spec.key_map, spec.key_map ~ '__key_map') }}
                where entity = '{{ entity }}'
            ) as key_map_rows,
            (select count(*) from {{ ref('sal_' ~ entity) }}) as sal_rows,
            (
                select count(*)
                from {{ ref('sal_' ~ entity) }} as sal
                left join {{ ref('hub_' ~ entity) }} as hub
                    on sal.{{ entity }}_v2_hk = hub.{{ entity }}_hk
                where hub.{{ entity }}_hk is null
            ) as v2_keys_missing_in_hub,
            (
                select count(distinct {{ spec.v1[2] }})
                from {{ source(spec.v1[0], spec.v1[1]) }}
            ) as v1_keys,
            (
                select count(distinct {{ spec.v2[2] }})
                from {{ source(spec.v2[0], spec.v2[1]) }}
            ) as v2_keys,
            (select count(*) from {{ ref('hub_' ~ entity) }}) as hub_rows
        {% if not loop.last %}
            union all
        {% endif %}
    {% endfor %}
),

v1_satellite_last_load as (
    {% for satellite in v1_satellites %}
        select
            '{{ satellite }}' as object_name,
            max(load_datetime) as last_load_datetime
        from {{ ref(satellite) }}
        {% if not loop.last %}
            union all
        {% endif %}
    {% endfor %}
)

select
    object_name,
    key_map_rows,
    sal_rows,
    v2_keys_missing_in_hub,
    v1_keys,
    v2_keys,
    v2_keys - key_map_rows as v2_keys_without_v1,
    hub_rows,
    hub_rows - sal_rows as business_entities,
    cast(null as date) as last_load_datetime
from entity_counts

union all

select
    object_name,
    null as key_map_rows,
    null as sal_rows,
    null as v2_keys_missing_in_hub,
    null as v1_keys,
    null as v2_keys,
    null as v2_keys_without_v1,
    null as hub_rows,
    null as business_entities,
    cast(last_load_datetime as date) as last_load_datetime
from v1_satellite_last_load
