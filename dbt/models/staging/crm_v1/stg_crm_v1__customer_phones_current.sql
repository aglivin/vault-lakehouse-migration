{{ automate_dv.stage(
    include_source_columns=true,
    source_model='stg_crm_v1__customer_phones_active_set',
    hashed_columns={
        'CUSTOMER_HK': 'CUSTOMER_NO',
        'PHONE_HASHDIFF': {'is_hashdiff': true, 'columns': ['PHONE_TYPE', 'PHONE_NUMBER']}
    }
) }}
