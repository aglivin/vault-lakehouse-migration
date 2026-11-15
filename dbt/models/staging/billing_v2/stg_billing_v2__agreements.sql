{{ vdwh.stage_raw(
    'billing_v2', 'agreements',
    {
        'CONTRACT_HK': 'AGREEMENT_ID',
        'CUSTOMER_HK': 'ACCOUNT_UUID',
        'TARIFF_HK': 'PRODUCT_CODE',
        'METER_HK': 'METER_POINT_ID',
        'CUSTOMER_CONTRACT_HK': ['ACCOUNT_UUID', 'AGREEMENT_ID'],
        'CONTRACT_METER_HK': ['AGREEMENT_ID', 'METER_POINT_ID'],
        'CONTRACT_DETAILS_HASHDIFF': {'is_hashdiff': true, 'columns': ['PRODUCT_CODE', 'METER_POINT_ID', 'VALID_FROM', 'VALID_TO', 'AGREEMENT_STATUS']}
    },
    {'CONTRACT_NO': 'agreement_id'}
) }}
