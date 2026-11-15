{{ config(materialized='incremental') }}

{{ automate_dv.sat(
    src_pk='INVOICE_HK',
    src_hashdiff='INVOICE_DETAILS_HASHDIFF',
    src_payload=['INVOICE_DATE', 'PERIOD_FROM', 'PERIOD_TO', 'DUE_DATE'],
    src_ldts='LOAD_DATETIME',
    src_source='RECORD_SOURCE',
    source_model='stg_billing_v1__invoices'
) }}
