select
    hub.contract_hk,
    coalesce(sal.contract_hk, hub.contract_hk) as master_contract_hk,
    coalesce(master_hub.contract_no, hub.contract_no) as master_contract_no
from {{ ref('hub_contract') }} as hub
left join {{ ref('sal_contract') }} as sal
    on hub.contract_hk = sal.contract_v2_hk
left join {{ ref('hub_contract') }} as master_hub
    on sal.contract_hk = master_hub.contract_hk
