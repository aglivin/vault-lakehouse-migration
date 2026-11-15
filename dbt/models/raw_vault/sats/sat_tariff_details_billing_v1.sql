{{ config(materialized='incremental') }}

{{ automate_dv.sat(
    src_pk='TARIFF_HK',
    src_hashdiff='TARIFF_DETAILS_HASHDIFF',
    src_payload=['COMMODITY', 'NAME', 'PRICE_PER_KWH', 'BASE_FEE_MONTH', 'VALID_FROM'],
    src_ldts='LOAD_DATETIME',
    src_source='RECORD_SOURCE',
    source_model='stg_billing_v1__tariffs'
) }}
