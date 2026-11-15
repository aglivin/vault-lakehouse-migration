{{ config(materialized='incremental') }}

{{ automate_dv.nh_link(
    src_pk='PAYMENT_HK',
    src_fk=['INVOICE_HK'],
    src_payload=['PAYMENT_ID', 'PAYMENT_DATE', 'AMOUNT'],
    src_eff='EFFECTIVE_FROM',
    src_ldts='LOAD_DATETIME',
    src_source='RECORD_SOURCE',
    source_model='stg_billing_v1__payments'
) }}
