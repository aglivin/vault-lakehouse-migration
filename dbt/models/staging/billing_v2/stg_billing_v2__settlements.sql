{{ vdwh.stage_raw(
    'billing_v2', 'settlements',
    {
        'PAYMENT_HK': 'PAYMENT_ID',
        'INVOICE_HK': 'DOCUMENT_ID'
    },
    {
        'PAYMENT_ID': 'settlement_id',
        'INVOICE_NO': 'document_id',
        'PAYMENT_DATE': 'settled_on',
        'AMOUNT': 'settled_amount',
        'EFFECTIVE_FROM': 'cast(settled_on as date)'
    }
) }}
