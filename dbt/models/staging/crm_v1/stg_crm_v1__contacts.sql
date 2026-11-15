{{ vdwh.stage_raw(
    'crm_v1', 'contacts',
    {
        'CONTACT_HK': 'CONTACT_ID',
        'CUSTOMER_HK': 'CUSTOMER_NO'
    },
    {'EFFECTIVE_FROM': 'cast(contact_ts as date)'}
) }}
