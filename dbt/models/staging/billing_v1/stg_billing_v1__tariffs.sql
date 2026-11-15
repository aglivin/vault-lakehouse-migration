{{ vdwh.stage_raw(
    'billing_v1', 'tariffs',
    {
        'TARIFF_HK': 'TARIFF_CODE',
        'TARIFF_DETAILS_HASHDIFF': {'is_hashdiff': true, 'columns': ['COMMODITY', 'NAME', 'PRICE_PER_KWH', 'BASE_FEE_MONTH', 'VALID_FROM']}
    }
) }}
