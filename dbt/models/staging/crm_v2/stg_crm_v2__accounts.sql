{{ vdwh.stage_raw(
    'crm_v2', 'accounts',
    {
        'CUSTOMER_HK': 'ACCOUNT_UUID',
        'CUSTOMER_DETAILS_HASHDIFF': {'is_hashdiff': true, 'columns': ['GIVEN_NAME', 'FAMILY_NAME', 'EMAIL_ADDRESS', 'DATE_OF_BIRTH', 'STREET_LINE', 'TOWN', 'ZIP', 'CUSTOMER_SEGMENT']}
    },
    {'CUSTOMER_NO': 'account_uuid'}
) }}
