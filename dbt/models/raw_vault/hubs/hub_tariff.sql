{{ config(materialized='incremental') }}

{{ automate_dv.hub(
    src_pk='TARIFF_HK',
    src_nk='TARIFF_CODE',
    src_ldts='LOAD_DATETIME',
    src_source='RECORD_SOURCE',
    source_model='stg_billing_v1__tariffs'
) }}
