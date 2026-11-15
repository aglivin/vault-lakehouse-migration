{{ config(materialized='incremental') }}

{{ automate_dv.link(
    src_pk='CUSTOMER_CONTRACT_HK',
    src_fk=['CUSTOMER_HK', 'CONTRACT_HK'],
    src_ldts='LOAD_DATETIME',
    src_source='RECORD_SOURCE',
    source_model='stg_billing_v1__contracts'
) }}
