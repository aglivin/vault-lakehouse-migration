{{ vdwh.stage_raw(
    'crm_v2', 'interactions',
    {
        'CONTACT_HK': 'INTERACTION_ID',
        'CUSTOMER_HK': 'ACCOUNT_UUID'
    },
    {
        'CONTACT_ID': 'interaction_id',
        'CUSTOMER_NO': 'account_uuid',
        'CONTACT_TS': 'occurred_at',
        'REASON': 'topic',
        'RESOLVED_FIRST_CONTACT': 'first_contact_resolution',
        'EFFECTIVE_FROM': 'cast(occurred_at as date)'
    }
) }}
