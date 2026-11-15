{{ config(materialized='incremental') }}

{{ automate_dv.ma_sat(
    src_pk='INVOICE_HK',
    src_cdk=['LINE_NO'],
    src_hashdiff='INVOICE_LINE_HASHDIFF',
    src_payload=['CHARGE_TYPE', 'PRODUCT_CODE', 'QUANTITY_KWH', 'AMOUNT_NET', 'VAT_RATE', 'VAT_AMOUNT'],
    src_ldts='LOAD_DATETIME',
    src_source='RECORD_SOURCE',
    source_model='stg_billing_v2__document_lines'
) }}
