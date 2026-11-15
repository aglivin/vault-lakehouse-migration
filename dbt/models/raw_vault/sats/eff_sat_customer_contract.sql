{{ config(materialized='incremental') }}

{% call vdwh.skip_loaded_load_dates('CUSTOMER_CONTRACT_HK') %}
    {{ automate_dv.eff_sat(
        src_pk='CUSTOMER_CONTRACT_HK',
        src_dfk='CONTRACT_HK',
        src_sfk='CUSTOMER_HK',
        src_start_date='EFF_START_DATE',
        src_end_date='EFF_END_DATE',
        src_eff='EFFECTIVE_FROM',
        src_ldts='LOAD_DATETIME',
        src_source='RECORD_SOURCE',
        source_model='stg_billing_v1__contracts'
    ) }}
{% endcall %}
