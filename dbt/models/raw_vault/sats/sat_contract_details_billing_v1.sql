{{ config(materialized='incremental') }}

{{ automate_dv.sat(
    src_pk='CONTRACT_HK',
    src_hashdiff='CONTRACT_DETAILS_HASHDIFF',
    src_payload=['TARIFF_CODE', 'METER_NO', 'START_DATE', 'END_DATE', 'STATUS'],
    src_ldts='LOAD_DATETIME',
    src_source='RECORD_SOURCE',
    source_model='stg_billing_v1__contracts'
) }}
