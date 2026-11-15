{{ config(materialized='incremental') }}

{{ automate_dv.link(
    src_pk='INVOICE_TARIFF_HK',
    src_fk=['INVOICE_HK', 'TARIFF_HK'],
    src_ldts='LOAD_DATETIME',
    src_source='RECORD_SOURCE',
    source_model=['stg_billing_v1__invoice_lines', 'stg_billing_v2__document_lines']
) }}
