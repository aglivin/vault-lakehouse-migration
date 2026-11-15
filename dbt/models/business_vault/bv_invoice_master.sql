select
    hub.invoice_hk,
    coalesce(sal.invoice_hk, hub.invoice_hk) as master_invoice_hk,
    coalesce(master_hub.invoice_no, hub.invoice_no) as master_invoice_no
from {{ ref('hub_invoice') }} as hub
left join {{ ref('sal_invoice') }} as sal
    on hub.invoice_hk = sal.invoice_v2_hk
left join {{ ref('hub_invoice') }} as master_hub
    on sal.invoice_hk = master_hub.invoice_hk
