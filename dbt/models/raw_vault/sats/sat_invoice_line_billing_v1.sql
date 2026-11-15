{{ config(materialized='incremental') }}

{{ automate_dv.ma_sat(
    src_pk='INVOICE_HK',
    src_cdk=['LINE_NO'],
    src_hashdiff='INVOICE_LINE_HASHDIFF',
    src_payload=['LINE_TYPE', 'TARIFF_CODE', 'KWH', 'NET_AMOUNT', 'TAX_RATE', 'TAX_AMOUNT'],
    src_ldts='LOAD_DATETIME',
    src_source='RECORD_SOURCE',
    source_model='stg_billing_v1__invoice_lines'
) }}
