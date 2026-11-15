with customer_contract as (
    select
        customer_master.master_customer_hk,
        contract_master.master_contract_hk,
        min(link.load_datetime) as first_load_datetime
    from {{ ref('link_customer_contract') }} as link
    inner join {{ ref('bv_customer_master') }} as customer_master
        on link.customer_hk = customer_master.customer_hk
    inner join {{ ref('bv_contract_master') }} as contract_master
        on link.contract_hk = contract_master.contract_hk
    group by
        customer_master.master_customer_hk,
        contract_master.master_contract_hk
),

contract_status as (
    select
        master.master_contract_hk,
        sts.load_datetime,
        sts.status
    from {{ ref('sts_contract') }} as sts
    inner join {{ ref('bv_contract_master') }} as master
        on sts.contract_hk = master.contract_hk
),

status_as_of as (
    select
        customer_contract.master_customer_hk,
        customer_contract.master_contract_hk,
        as_of_dates.as_of_date,
        contract_status.status,
        row_number() over (
            partition by
                customer_contract.master_customer_hk,
                customer_contract.master_contract_hk,
                as_of_dates.as_of_date
            order by contract_status.load_datetime desc
        ) as recency
    from customer_contract
    inner join {{ ref('as_of_dates') }} as as_of_dates
        on
            cast(customer_contract.first_load_datetime as date)
            <= as_of_dates.as_of_date
    left join contract_status
        on
            customer_contract.master_contract_hk
            = contract_status.master_contract_hk
            and cast(contract_status.load_datetime as date)
            <= as_of_dates.as_of_date
)

select
    master_customer_hk as customer_hk,
    master_contract_hk as contract_hk,
    as_of_date
from status_as_of
where recency = 1 and coalesce(status, 'I') <> 'D'
