{{ vdwh.stage_raw(
    'billing_v1', 'invoices',
    {'INVOICE_HK': 'INVOICE_NO', 'CONTRACT_HK': 'CONTRACT_NO'},
    required_key='invoice_no'
) }}
