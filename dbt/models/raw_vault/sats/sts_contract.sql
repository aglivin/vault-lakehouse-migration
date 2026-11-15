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
    stored_before as (
        select
            staged.contract_hk,
            staged.load_datetime,
            stored.status,
            row_number()
                over (
                    partition by staged.contract_hk, staged.load_datetime
                    order by stored.load_datetime desc
                )
                as recency
        from staged
        inner join {{ this }} as stored
            on
                staged.contract_hk = stored.contract_hk
                and staged.load_datetime > stored.load_datetime
    ),

    compared as (
        select
            staged.contract_hk,
            staged.load_datetime,
            staged.status,
            staged.record_source,
            coalesce(staged.previous_staged_status, stored_before.status)
                as previous_status
        from staged
        left join stored_before
            on
                staged.contract_hk = stored_before.contract_hk
                and staged.load_datetime = stored_before.load_datetime
                and stored_before.recency = 1
        where not exists (
            select 1
            from {{ this }} as existing
            where
                existing.contract_hk = staged.contract_hk
                and existing.load_datetime = staged.load_datetime
        )
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
