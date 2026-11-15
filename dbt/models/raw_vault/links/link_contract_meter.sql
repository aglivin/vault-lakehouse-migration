{{ config(materialized='incremental') }}

{{ automate_dv.link(
    src_pk='CONTRACT_METER_HK',
    src_fk=['CONTRACT_HK', 'METER_HK'],
    src_ldts='LOAD_DATETIME',
    src_source='RECORD_SOURCE',
    source_model=['stg_billing_v1__contracts', 'stg_billing_v2__agreements']
) }}
