{{ config(materialized='incremental') }}

{% call vdwh.skip_loaded_load_dates('CUSTOMER_HK') %}
    {{ automate_dv.ma_sat(
        src_pk='CUSTOMER_HK',
        src_cdk=['PHONE_TYPE'],
        src_hashdiff='PHONE_HASHDIFF',
        src_payload=['PHONE_NUMBER'],
        src_ldts='LOAD_DATETIME',
        src_source='RECORD_SOURCE',
        source_model='stg_crm_v1__customer_phones_current'
    ) }}
{% endcall %}
