{{ vdwh.stage_raw(
    'billing_v1', 'invoice_lines',
    {
        'INVOICE_HK': 'INVOICE_NO',
        'TARIFF_HK': 'TARIFF_CODE',
        'INVOICE_TARIFF_HK': ['INVOICE_NO', 'TARIFF_CODE'],
        'INVOICE_LINE_HASHDIFF': {'is_hashdiff': true, 'columns': ['LINE_NO', 'LINE_TYPE', 'TARIFF_CODE', 'KWH', 'NET_AMOUNT', 'TAX_RATE', 'TAX_AMOUNT']}
    }
) }}
