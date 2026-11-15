{{ config(materialized='incremental') }}

{{ automate_dv.hub(
    src_pk='CUSTOMER_HK',
    src_nk='CUSTOMER_NO',
    src_ldts='LOAD_DATETIME',
    src_source='RECORD_SOURCE',
    source_model=['stg_crm_v1__customers', 'stg_crm_v2__accounts']
) }}
