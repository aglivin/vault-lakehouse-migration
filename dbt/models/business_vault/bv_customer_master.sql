select
    hub.customer_hk,
    coalesce(sal.customer_hk, hub.customer_hk) as master_customer_hk,
    coalesce(master_hub.customer_no, hub.customer_no) as master_customer_no
from {{ ref('hub_customer') }} as hub
left join {{ ref('sal_customer') }} as sal
    on hub.customer_hk = sal.customer_v2_hk
left join {{ ref('hub_customer') }} as master_hub
    on sal.customer_hk = master_hub.customer_hk
