{{
    config(
        cluster_by=['tariff_code', 'invoice_date'],
        liquid_clustered_by=['tariff_code', 'invoice_date'],
        event_time='invoice_date'
    )
}}

with invoice_master as (
    select
        invoice_hk,
        master_invoice_hk,
        master_invoice_no
    from {{ ref('bv_invoice_master') }}
),

line_rows as (
    select
        invoice_hk,
        load_datetime,
        line_no,
        line_type,
        tariff_code,
        kwh,
        net_amount,
        tax_rate,
        tax_amount
    from {{ ref('sat_invoice_line_billing_v1') }}
    union all
    select
        invoice_hk,
        load_datetime,
        line_no,
        charge_type as line_type,
        product_code as tariff_code,
        quantity_kwh as kwh,
        amount_net as net_amount,
        vat_rate as tax_rate,
        vat_amount as tax_amount
    from {{ ref('sat_invoice_line_billing_v2') }}
),

latest_lines as (
    select
        invoice_master.master_invoice_hk,
        invoice_master.master_invoice_no,
        line_rows.line_no,
        line_rows.line_type,
        line_rows.tariff_code,
        line_rows.kwh,
        line_rows.net_amount,
        line_rows.tax_rate,
        line_rows.tax_amount
    from line_rows
    inner join invoice_master
        on line_rows.invoice_hk = invoice_master.invoice_hk
    qualify
        line_rows.load_datetime
        = max(line_rows.load_datetime)
            over (partition by invoice_master.master_invoice_hk)
),

header_rows as (
    select
        invoice_hk,
        load_datetime,
        invoice_date,
        period_from,
        period_to,
        due_date
    from {{ ref('sat_invoice_details_billing_v1') }}
    union all
    select
        invoice_hk,
        load_datetime,
        issued_on as invoice_date,
        billing_from as period_from,
        billing_to as period_to,
        payable_by as due_date
    from {{ ref('sat_invoice_details_billing_v2') }}
),

latest_header as (
    select
        invoice_master.master_invoice_hk,
        header_rows.invoice_date,
        header_rows.period_from,
        header_rows.period_to,
        header_rows.due_date
    from header_rows
    inner join invoice_master
        on header_rows.invoice_hk = invoice_master.invoice_hk
    qualify
        row_number() over (
            partition by invoice_master.master_invoice_hk
            order by header_rows.load_datetime desc
        ) = 1
),

invoice_contract as (
    select
        invoice_master.master_invoice_hk,
        contract_master.master_contract_no
    from {{ ref('link_contract_invoice') }} as link_contract_invoice
    inner join invoice_master
        on link_contract_invoice.invoice_hk = invoice_master.invoice_hk
    inner join {{ ref('bv_contract_master') }} as contract_master
        on link_contract_invoice.contract_hk = contract_master.contract_hk
    qualify
        row_number() over (
            partition by invoice_master.master_invoice_hk
            order by link_contract_invoice.load_datetime desc
        ) = 1
),

tariff_master as (
    select
        hub_tariff.tariff_code,
        bv_tariff_master.master_tariff_no
    from {{ ref('hub_tariff') }} as hub_tariff
    inner join {{ ref('bv_tariff_master') }} as bv_tariff_master
        on hub_tariff.tariff_hk = bv_tariff_master.tariff_hk
)

select
    lines.master_invoice_no as invoice_no,
    cast(lines.line_no as integer) as line_no,
    invoice_contract.master_contract_no as contract_no,
    cast(invoice_header.invoice_date as date) as invoice_date,
    cast(invoice_header.period_from as date) as period_from,
    cast(invoice_header.period_to as date) as period_to,
    cast(invoice_header.due_date as date) as due_date,
    tariff_master.master_tariff_no as tariff_code,
    lines.line_type,
    cast(lines.kwh as decimal(18, 3)) as kwh,
    cast(lines.net_amount as decimal(18, 2)) as net_amount,
    cast(lines.tax_rate as decimal(18, 2)) as tax_rate,
    cast(lines.tax_amount as decimal(18, 2)) as tax_amount
from latest_lines as lines
inner join latest_header as invoice_header
    on lines.master_invoice_hk = invoice_header.master_invoice_hk
inner join invoice_contract
    on lines.master_invoice_hk = invoice_contract.master_invoice_hk
left join tariff_master
    on lines.tariff_code = tariff_master.tariff_code
