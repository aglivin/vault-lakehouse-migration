{{
    config(
        enabled=var('perf_strategy', none) is not none,
        materialized='incremental',
        incremental_strategy=var('perf_strategy', 'merge'),
        alias='perf_invoice_line_' ~ var('perf_strategy', 'merge') | replace('+', '_'),
        unique_key=['invoice_no', 'line_no'],
        partition_by=['invoice_date'],
        event_time='invoice_date',
        batch_size='day',
        begin='2026-01-01',
        on_schema_change='fail'
    )
}}

select
    invoice_no,
    line_no,
    contract_no,
    invoice_date,
    tariff_code,
    line_type,
    kwh,
    net_amount,
    tax_amount
from {{ ref('fct_invoice_line') }}
{% if is_incremental() and var('perf_strategy') != 'microbatch' %}
    where invoice_date >= (
        select max(this_table.invoice_date)
        from {{ this }} as this_table
    )
{% endif %}
