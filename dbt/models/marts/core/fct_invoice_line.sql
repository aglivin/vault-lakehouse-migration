with latest_invoice_details as (
    select
        invoice_hk,
        invoice_date,
        period_from,
        period_to
    from {{ ref('sat_invoice_details_billing_v1') }}
    qualify
        row_number() over (
            partition by invoice_hk order by load_datetime desc
        ) = 1
),

latest_invoice_lines as (
    select
        invoice_hk,
        line_no,
        line_type,
        tariff_code,
        kwh,
        net_amount,
        tax_rate,
        tax_amount
    from {{ ref('sat_invoice_line_billing_v1') }}
    qualify load_datetime = max(load_datetime) over (partition by invoice_hk)
)

select
    hub_invoice.invoice_no,
    cast(lines.line_no as integer) as line_no,
    hub_contract.contract_no,
    cast(details.invoice_date as date) as invoice_date,
    cast(details.period_from as date) as period_from,
    cast(details.period_to as date) as period_to,
    lines.tariff_code,
    lines.line_type,
    cast(lines.kwh as decimal(18, 3)) as kwh,
    cast(lines.net_amount as decimal(18, 2)) as net_amount,
    cast(lines.tax_rate as decimal(18, 2)) as tax_rate,
    cast(lines.tax_amount as decimal(18, 2)) as tax_amount
from latest_invoice_lines as lines
inner join {{ ref('hub_invoice') }} as hub_invoice
    on lines.invoice_hk = hub_invoice.invoice_hk
inner join latest_invoice_details as details
    on lines.invoice_hk = details.invoice_hk
inner join {{ ref('link_contract_invoice') }} as link_contract_invoice
    on lines.invoice_hk = link_contract_invoice.invoice_hk
inner join {{ ref('hub_contract') }} as hub_contract
    on link_contract_invoice.contract_hk = hub_contract.contract_hk
