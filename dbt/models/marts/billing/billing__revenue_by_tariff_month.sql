with invoice_lines as (
    select
        invoice_no,
        tariff_code,
        line_type,
        kwh,
        net_amount,
        tax_amount,
        {{ month_trunc('invoice_date') }} as invoice_month
    from {{ ref('fct_invoice_line') }}
)

select
    ln.invoice_month,
    ln.tariff_code,
    dim.commodity,
    cast(count(distinct ln.invoice_no) as integer) as invoice_count,
    cast(sum(
        case when ln.line_type = 'energy' then ln.kwh else 0 end
    ) as decimal(18, 3)) as kwh,
    cast(sum(ln.net_amount) as decimal(18, 2)) as net_amount,
    cast(sum(
        case when ln.line_type = 'vat' then ln.tax_amount else 0 end
    ) as decimal(18, 2)) as vat_amount
from invoice_lines as ln
inner join {{ ref('dim_tariff') }} as dim
    on ln.tariff_code = dim.tariff_code
group by 1, 2, 3
