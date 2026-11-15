{{ vdwh.stage_raw(
    'billing_v1', 'payments',
    {
        'PAYMENT_HK': 'PAYMENT_ID',
        'INVOICE_HK': 'INVOICE_NO'
    },
    {'EFFECTIVE_FROM': 'cast(payment_date as date)'}
) }}
