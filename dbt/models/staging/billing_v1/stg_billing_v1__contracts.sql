{{ vdwh.stage_raw(
    'billing_v1', 'contracts',
    {
        'CONTRACT_HK': 'CONTRACT_NO',
        'CUSTOMER_HK': 'CUSTOMER_NO',
        'TARIFF_HK': 'TARIFF_CODE',
        'METER_HK': 'METER_NO',
        'CUSTOMER_CONTRACT_HK': ['CUSTOMER_NO', 'CONTRACT_NO'],
        'CONTRACT_METER_HK': ['CONTRACT_NO', 'METER_NO'],
        'CONTRACT_DETAILS_HASHDIFF': {'is_hashdiff': true, 'columns': ['TARIFF_CODE', 'METER_NO', 'START_DATE', 'END_DATE', 'STATUS']}
    },
    {
        'EFFECTIVE_FROM': 'cast(start_date as date)',
        'EFF_START_DATE': 'cast(start_date as date)',
        'EFF_END_DATE': "case when op = 'D' then _load_date else coalesce(cast(end_date as date), cast('9999-12-31' as date)) end"
    }
) }}
