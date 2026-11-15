{{ config(materialized='incremental') }}

with staged as (
    select
        contract_hk,
        load_datetime,
        op as status,
        record_source,
        lag(op)
            over (partition by contract_hk order by load_datetime)
            as previous_staged_status
    from {{ ref('stg_billing_v1__contracts') }}
),

{% if is_incremental() %}
    ranked_stored as (
        select
            contract_hk,
            status,
            row_number()
                over (partition by contract_hk order by load_datetime desc)
                as recency
        from {{ this }}
    ),

    latest_stored as (
        select
            contract_hk,
            status
        from ranked_stored
        where recency = 1
    ),

    compared as (
        select
            staged.contract_hk,
            staged.load_datetime,
            staged.status,
            staged.record_source,
            coalesce(staged.previous_staged_status, latest_stored.status)
                as previous_status
        from staged
        left join
            latest_stored
            on staged.contract_hk = latest_stored.contract_hk
    )
{% else %}
    compared as (
        select
            contract_hk,
            load_datetime,
            status,
            record_source,
            previous_staged_status as previous_status
        from staged
    )
{% endif %}

select
    contract_hk,
    load_datetime,
    status,
    record_source
from compared
where
    previous_status is null
    or previous_status <> status
