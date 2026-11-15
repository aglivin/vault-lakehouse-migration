select
    'sat_customer_phone_ma' as table_name,
    cast(customer_hk as string) || '|' || phone_type || '|' || cast(load_datetime as string) as duplicate_grain
from {{ ref('sat_customer_phone_ma') }}
group by customer_hk, phone_type, load_datetime
having count(*) > 1

union all

select
    'eff_sat_customer_contract' as table_name,
    cast(customer_contract_hk as string) || '|' || cast(load_datetime as string) as duplicate_grain
from {{ ref('eff_sat_customer_contract') }}
group by customer_contract_hk, load_datetime
having count(*) > 1

union all

select
    'sts_contract' as table_name,
    cast(contract_hk as string) || '|' || cast(load_datetime as string) as duplicate_grain
from {{ ref('sts_contract') }}
group by contract_hk, load_datetime
having count(*) > 1
