{{ config(materialized='incremental') }}

{{ automate_dv.sat(
    src_pk='CUSTOMER_HK',
    src_hashdiff='CUSTOMER_DETAILS_HASHDIFF',
    src_payload=['GIVEN_NAME', 'FAMILY_NAME', 'EMAIL_ADDRESS', 'DATE_OF_BIRTH', 'STREET_LINE', 'TOWN', 'ZIP', 'CUSTOMER_SEGMENT'],
    src_ldts='LOAD_DATETIME',
    src_source='RECORD_SOURCE',
    source_model='stg_crm_v2__accounts'
) }}
