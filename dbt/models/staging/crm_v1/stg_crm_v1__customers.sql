{{ vdwh.stage_raw(
    'crm_v1', 'customers',
    {
        'CUSTOMER_HK': 'CUSTOMER_NO',
        'CUSTOMER_DETAILS_HASHDIFF': {'is_hashdiff': true, 'columns': ['FIRST_NAME', 'LAST_NAME', 'EMAIL', 'BIRTH_DATE', 'STREET', 'CITY', 'POSTAL_CODE', 'SEGMENT']}
    }
) }}
