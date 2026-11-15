{{ vdwh.stage_raw(
    'billing_v2', 'products',
    {
        'TARIFF_HK': 'PRODUCT_CODE',
        'TARIFF_DETAILS_HASHDIFF': {'is_hashdiff': true, 'columns': ['COMMODITY', 'PRODUCT_NAME', 'UNIT_PRICE_KWH', 'MONTHLY_FEE', 'AVAILABLE_FROM']}
    },
    {'TARIFF_CODE': 'product_code'}
) }}
