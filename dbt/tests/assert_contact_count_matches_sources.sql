with v1_groups as (
    select
        customer_master.master_customer_hk,
        cast(nhl.contact_ts as timestamp) as contact_ts,
        nhl.channel,
        nhl.reason,
        count(*) as contact_count
    from {{ ref('nhl_contact_crm_v1') }} as nhl
    inner join {{ ref('bv_customer_master') }} as customer_master
        on nhl.customer_hk = customer_master.customer_hk
    group by 1, 2, 3, 4
),

v2_groups as (
    select
        customer_master.master_customer_hk,
        cast(nhl.contact_ts as timestamp) as contact_ts,
        nhl.channel,
        nhl.reason,
        count(*) as contact_count
    from {{ ref('nhl_contact_crm_v2') }} as nhl
    inner join {{ ref('bv_customer_master') }} as customer_master
        on nhl.customer_hk = customer_master.customer_hk
    group by 1, 2, 3, 4
),

expected as (
    select
        sum(
            greatest(
                coalesce(v1_groups.contact_count, 0),
                coalesce(v2_groups.contact_count, 0)
            )
        ) as expected_count
    from v1_groups
    full outer join v2_groups
        on v1_groups.master_customer_hk = v2_groups.master_customer_hk
            and v1_groups.contact_ts = v2_groups.contact_ts
            and v1_groups.channel = v2_groups.channel
            and v1_groups.reason = v2_groups.reason
),

actual as (
    select count(*) as actual_count
    from {{ ref('fct_contact') }}
)

select
    expected.expected_count,
    actual.actual_count
from expected
cross join actual
where expected.expected_count is null
    or expected.expected_count = 0
    or expected.expected_count != actual.actual_count
