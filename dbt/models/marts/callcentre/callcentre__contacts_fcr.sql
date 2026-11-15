with contact_rows as (
    select
        customer_hk,
        contact_ts,
        channel,
        reason,
        resolved_first_contact,
        1 as source_rank
    from {{ ref('nhl_contact_crm_v1') }}
    union all
    select
        customer_hk,
        contact_ts,
        channel,
        reason,
        resolved_first_contact,
        2 as source_rank
    from {{ ref('nhl_contact_crm_v2') }}
),

master_contacts as (
    select
        customer_master.master_customer_hk,
        cast(contact_rows.contact_ts as timestamp) as contact_ts,
        contact_rows.channel,
        contact_rows.reason,
        lower(contact_rows.resolved_first_contact) = 'true'
            as is_resolved_first_contact
    from contact_rows
    inner join {{ ref('bv_customer_master') }} as customer_master
        on contact_rows.customer_hk = customer_master.customer_hk
    qualify
        row_number() over (
            partition by
                customer_master.master_customer_hk,
                cast(contact_rows.contact_ts as timestamp),
                contact_rows.channel,
                contact_rows.reason
            order by contact_rows.source_rank
        ) = 1
)

select
    {{ month_trunc('cast(contact_ts as date)') }} as contact_month,
    channel,
    reason,
    cast(count(*) as integer) as contact_count,
    cast(
        sum(case when is_resolved_first_contact then 1 else 0 end) as integer
    ) as resolved_first_contact_count,
    cast(
        sum(case when is_resolved_first_contact then 1 else 0 end)
        * 1.0 / count(*)
        as decimal(9, 4)
    ) as fcr_rate
from master_contacts
group by 1, 2, 3
