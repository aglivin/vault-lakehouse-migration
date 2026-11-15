select
    hub.tariff_hk,
    coalesce(sal.tariff_hk, hub.tariff_hk) as master_tariff_hk,
    coalesce(master_hub.tariff_code, hub.tariff_code) as master_tariff_no
from {{ ref('hub_tariff') }} as hub
left join {{ ref('sal_tariff') }} as sal
    on hub.tariff_hk = sal.tariff_v2_hk
left join {{ ref('hub_tariff') }} as master_hub
    on sal.tariff_hk = master_hub.tariff_hk
