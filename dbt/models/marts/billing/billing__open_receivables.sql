with invoice_totals as (
    select
        invoice_no,
        contract_no,
        invoice_date,
        sum(net_amount) + sum(
            case when line_type = 'vat' then tax_amount else 0 end
        ) as gross_amount
    from {{ ref('fct_invoice_line') }}
    group by 1, 2, 3
),

paid as (
    select
        invoice_no,
        sum(amount) as paid_amount
    from {{ ref('fct_payment') }}
    group by 1
)

select
    invoice_totals.invoice_no,
    invoice_totals.contract_no,
    dim_contract.customer_no,
    invoice_totals.invoice_date,
    cast(invoice_totals.gross_amount as decimal(18, 2)) as gross_amount,
    cast(coalesce(paid.paid_amount, 0) as decimal(18, 2)) as paid_amount,
    cast(
        invoice_totals.gross_amount - coalesce(paid.paid_amount, 0)
        as decimal(18, 2)
    ) as open_amount
from invoice_totals
inner join {{ ref('dim_contract') }} as dim_contract
    on invoice_totals.contract_no = dim_contract.contract_no
left join paid
    on invoice_totals.invoice_no = paid.invoice_no
where invoice_totals.gross_amount - coalesce(paid.paid_amount, 0) > 0
