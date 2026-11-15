select
    hub.meter_hk,
    coalesce(sal.meter_hk, hub.meter_hk) as master_meter_hk,
    coalesce(master_hub.meter_no, hub.meter_no) as master_meter_no
from {{ ref('hub_meter') }} as hub
left join {{ ref('sal_meter') }} as sal
    on hub.meter_hk = sal.meter_v2_hk
left join {{ ref('hub_meter') }} as master_hub
    on sal.meter_hk = master_hub.meter_hk
