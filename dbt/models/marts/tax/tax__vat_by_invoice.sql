select
    invoice_no,
    contract_no,
    invoice_date,
    cast(
        max(case when line_type = 'vat' then tax_rate end) as decimal(18, 2)
    ) as vat_rate,
    cast(sum(net_amount) as decimal(18, 2)) as net_amount,
    cast(
        sum(case when line_type = 'vat' then tax_amount else 0 end)
        as decimal(18, 2)
    ) as vat_amount
from {{ ref('fct_invoice_line') }}
group by 1, 2, 3
