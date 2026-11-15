{{ config(materialized='incremental') }}

{{ automate_dv.hub(
    src_pk='METER_HK',
    src_nk='METER_NO',
    src_ldts='LOAD_DATETIME',
    src_source='RECORD_SOURCE',
    source_model='stg_billing_v1__meters'
) }}
