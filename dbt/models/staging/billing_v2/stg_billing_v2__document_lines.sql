{{ vdwh.stage_raw(
    'billing_v2', 'document_lines',
    {
        'INVOICE_HK': 'DOCUMENT_ID',
        'TARIFF_HK': 'PRODUCT_CODE',
        'INVOICE_TARIFF_HK': ['DOCUMENT_ID', 'PRODUCT_CODE'],
        'INVOICE_LINE_HASHDIFF': {'is_hashdiff': true, 'columns': ['POSITION', 'CHARGE_TYPE', 'PRODUCT_CODE', 'QUANTITY_KWH', 'AMOUNT_NET', 'VAT_RATE', 'VAT_AMOUNT']}
    },
    {'LINE_NO': 'position'}
) }}
