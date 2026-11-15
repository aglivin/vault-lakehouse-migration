with raw_contracts as (
    select
        contract_no,
        op,
        _load_date as load_date
    from {{ source('billing_v1', 'billing_v1__contracts') }}
    where _load_date <= (select max(load_datetime) from {{ ref('sts_contract') }})
),

raw_delete_then_insert as (
    select distinct deleted.contract_no
    from raw_contracts as deleted
    inner join raw_contracts as inserted
        on deleted.contract_no = inserted.contract_no
            and inserted.load_date > deleted.load_date
    where deleted.op = 'D'
        and inserted.op = 'I'
),

vault_delete_then_insert as (
    select distinct deleted.contract_hk
    from {{ ref('sts_contract') }} as deleted
    inner join {{ ref('sts_contract') }} as inserted
        on deleted.contract_hk = inserted.contract_hk
            and inserted.load_datetime > deleted.load_datetime
    where deleted.status = 'D'
        and inserted.status = 'I'
)

select
    raw_delete_then_insert.contract_no,
    'missing D then I in sts_contract' as failure
from raw_delete_then_insert
inner join {{ ref('hub_contract') }} as hub
    on raw_delete_then_insert.contract_no = hub.contract_no
left join vault_delete_then_insert
    on hub.contract_hk = vault_delete_then_insert.contract_hk
where vault_delete_then_insert.contract_hk is null

union all

select
    cast(null as string) as contract_no,
    'no contract with D then I in raw' as failure
from (select count(*) as total from raw_delete_then_insert) as counts
where counts.total = 0
    and (select count(distinct load_datetime) from {{ ref('sts_contract') }}) >= 3
