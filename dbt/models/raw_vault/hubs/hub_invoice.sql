{{ config(materialized='incremental') }}

{{ automate_dv.hub(
    src_pk='INVOICE_HK',
    src_nk='INVOICE_NO',
    src_ldts='LOAD_DATETIME',
    src_source='RECORD_SOURCE',
    source_model=['stg_billing_v1__invoices', 'stg_billing_v2__documents']
) }}
