with v1_contacts as (
    select
        customer_master.master_customer_hk,
        customer_master.master_customer_no,
        nhl.contact_id,
        cast(nhl.contact_ts as timestamp) as contact_ts,
        nhl.channel,
        nhl.reason,
        lower(nhl.resolved_first_contact) = 'true'
            as is_resolved_first_contact,
        row_number() over (
            partition by
                customer_master.master_customer_hk,
                cast(nhl.contact_ts as timestamp),
                nhl.channel,
                nhl.reason
            order by nhl.contact_id
        ) as occurrence_no
    from {{ ref('nhl_contact_crm_v1') }} as nhl
    inner join {{ ref('bv_customer_master') }} as customer_master
        on nhl.customer_hk = customer_master.customer_hk
),

v2_contacts as (
    select
        customer_master.master_customer_hk,
        customer_master.master_customer_no,
        nhl.contact_id,
        cast(nhl.contact_ts as timestamp) as contact_ts,
        nhl.channel,
        nhl.reason,
        lower(nhl.resolved_first_contact) = 'true'
            as is_resolved_first_contact,
        row_number() over (
            partition by
                customer_master.master_customer_hk,
                cast(nhl.contact_ts as timestamp),
                nhl.channel,
                nhl.reason
            order by nhl.contact_id
        ) as occurrence_no
    from {{ ref('nhl_contact_crm_v2') }} as nhl
    inner join {{ ref('bv_customer_master') }} as customer_master
        on nhl.customer_hk = customer_master.customer_hk
),

v2_without_v1 as (
    select
        v2_contacts.master_customer_no,
        v2_contacts.contact_id,
        v2_contacts.contact_ts,
        v2_contacts.channel,
        v2_contacts.reason,
        v2_contacts.is_resolved_first_contact
    from v2_contacts
    left join v1_contacts
        on
            v2_contacts.master_customer_hk = v1_contacts.master_customer_hk
            and v2_contacts.contact_ts = v1_contacts.contact_ts
            and v2_contacts.channel = v1_contacts.channel
            and v2_contacts.reason = v1_contacts.reason
            and v2_contacts.occurrence_no = v1_contacts.occurrence_no
    where v1_contacts.contact_id is null
),

all_contacts as (
    select
        master_customer_no,
        contact_id,
        contact_ts,
        channel,
        reason,
        is_resolved_first_contact
    from v1_contacts
    union all
    select
        master_customer_no,
        contact_id,
        contact_ts,
        channel,
        reason,
        is_resolved_first_contact
    from v2_without_v1
)

select
    contact_id,
    master_customer_no as customer_no,
    contact_ts,
    cast(contact_ts as date) as contact_date,
    channel,
    reason,
    is_resolved_first_contact
from all_contacts
