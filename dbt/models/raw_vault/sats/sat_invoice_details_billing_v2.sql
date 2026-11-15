{{ config(materialized='incremental') }}

{{ automate_dv.sat(
    src_pk='INVOICE_HK',
    src_hashdiff='INVOICE_DETAILS_HASHDIFF',
    src_payload=['ISSUED_ON', 'BILLING_FROM', 'BILLING_TO', 'PAYABLE_BY'],
    src_ldts='LOAD_DATETIME',
    src_source='RECORD_SOURCE',
    source_model='stg_billing_v2__documents'
) }}
