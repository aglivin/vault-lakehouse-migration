{{ config(materialized='incremental') }}

{{ automate_dv.hub(
    src_pk='CONTRACT_HK',
    src_nk='CONTRACT_NO',
    src_ldts='LOAD_DATETIME',
    src_source='RECORD_SOURCE',
    source_model='stg_billing_v1__contracts'
) }}
