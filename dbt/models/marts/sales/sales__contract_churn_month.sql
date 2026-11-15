with contracts as (
    select
        start_date,
        end_date,
        lower(status) as status
    from {{ ref('dim_contract') }}
    where not is_deleted
),

started as (
    select
        {{ month_trunc('start_date') }} as contract_month,
        count(*) as started_contracts,
        0 as terminated_contracts
    from contracts
    group by 1
),

terminated as (
    select
        {{ month_trunc('end_date') }} as contract_month,
        0 as started_contracts,
        count(*) as terminated_contracts
    from contracts
    where status = 'terminated' and end_date is not null
    group by 1
),

monthly as (
    select
        contract_month,
        started_contracts,
        terminated_contracts
    from started
    union all
    select
        contract_month,
        started_contracts,
        terminated_contracts
    from terminated
)

select
    contract_month,
    cast(sum(started_contracts) as integer) as started_contracts,
    cast(sum(terminated_contracts) as integer) as terminated_contracts,
    cast(
        sum(started_contracts) - sum(terminated_contracts) as integer
    ) as net_contract_change
from monthly
group by 1
