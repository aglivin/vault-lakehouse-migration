{{ config(materialized='incremental') }}

{{ automate_dv.nh_link(
    src_pk='CONTACT_HK',
    src_fk=['CUSTOMER_HK'],
    src_payload=['CONTACT_ID', 'CONTACT_TS', 'CHANNEL', 'REASON', 'RESOLVED_FIRST_CONTACT'],
    src_eff='EFFECTIVE_FROM',
    src_ldts='LOAD_DATETIME',
    src_source='RECORD_SOURCE',
    source_model='stg_crm_v2__interactions'
) }}
