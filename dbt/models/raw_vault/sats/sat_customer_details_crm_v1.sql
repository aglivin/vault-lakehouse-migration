{{ config(materialized='incremental') }}

{{ automate_dv.sat(
    src_pk='CUSTOMER_HK',
    src_hashdiff='CUSTOMER_DETAILS_HASHDIFF',
    src_payload=['FIRST_NAME', 'LAST_NAME', 'EMAIL', 'BIRTH_DATE', 'STREET', 'CITY', 'POSTAL_CODE', 'SEGMENT'],
    src_ldts='LOAD_DATETIME',
    src_source='RECORD_SOURCE',
    source_model='stg_crm_v1__customers'
) }}
