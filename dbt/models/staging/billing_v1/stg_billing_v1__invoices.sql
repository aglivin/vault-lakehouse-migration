{{ vdwh.stage_raw(
    'billing_v1', 'invoices',
    {
        'INVOICE_HK': 'INVOICE_NO',
        'CONTRACT_HK': 'CONTRACT_NO',
        'CONTRACT_INVOICE_HK': ['CONTRACT_NO', 'INVOICE_NO'],
        'INVOICE_DETAILS_HASHDIFF': {'is_hashdiff': true, 'columns': ['INVOICE_DATE', 'PERIOD_FROM', 'PERIOD_TO', 'DUE_DATE']}
    }
) }}
