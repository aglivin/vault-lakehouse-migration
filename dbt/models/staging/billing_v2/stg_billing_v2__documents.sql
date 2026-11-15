{{ vdwh.stage_raw(
    'billing_v2', 'documents',
    {
        'INVOICE_HK': 'DOCUMENT_ID',
        'CONTRACT_HK': 'AGREEMENT_ID',
        'CONTRACT_INVOICE_HK': ['AGREEMENT_ID', 'DOCUMENT_ID'],
        'INVOICE_DETAILS_HASHDIFF': {'is_hashdiff': true, 'columns': ['ISSUED_ON', 'BILLING_FROM', 'BILLING_TO', 'PAYABLE_BY']}
    },
    {'INVOICE_NO': 'document_id'}
) }}
