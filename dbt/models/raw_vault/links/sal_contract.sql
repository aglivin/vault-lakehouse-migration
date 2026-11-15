{{ config(materialized='incremental') }}

{{ automate_dv.link(
    src_pk='SAL_CONTRACT_HK',
    src_fk=['CONTRACT_HK', 'CONTRACT_V2_HK'],
    src_ldts='LOAD_DATETIME',
    src_source='RECORD_SOURCE',
    source_model='stg_billing_v2__key_map'
) }}
