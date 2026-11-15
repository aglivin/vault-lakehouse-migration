{{ config(materialized='incremental') }}

{{ automate_dv.sat(
    src_pk='CONTRACT_HK',
    src_hashdiff='CONTRACT_DETAILS_HASHDIFF',
    src_payload=['PRODUCT_CODE', 'METER_POINT_ID', 'VALID_FROM', 'VALID_TO', 'AGREEMENT_STATUS'],
    src_ldts='LOAD_DATETIME',
    src_source='RECORD_SOURCE',
    source_model='stg_billing_v2__agreements'
) }}
