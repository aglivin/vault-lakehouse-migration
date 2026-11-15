{{ config(materialized='incremental') }}

{{ automate_dv.link(
    src_pk='SAL_CUSTOMER_HK',
    src_fk=['CUSTOMER_HK', 'CUSTOMER_V2_HK'],
    src_ldts='LOAD_DATETIME',
    src_source='RECORD_SOURCE',
    source_model='stg_crm_v2__key_map'
) }}
