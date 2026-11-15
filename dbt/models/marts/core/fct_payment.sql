with source_payments as (
    select
        invoice_hk,
        payment_id,
        payment_date,
        amount,
        'v1' as source
    from {{ ref('nhl_payment_billing_v1') }}
    union all
    select
        invoice_hk,
        payment_id,
        payment_date,
        amount,
        'v2' as source
    from {{ ref('nhl_payment_billing_v2') }}
),

numbered_payments as (
    select
        master.master_invoice_hk,
        master.master_invoice_no,
        source_payments.source,
        source_payments.payment_id,
        cast(source_payments.payment_date as date) as payment_date,
        cast(source_payments.amount as decimal(18, 2)) as amount,
        row_number() over (
            partition by
                master.master_invoice_hk,
                source_payments.source,
                cast(source_payments.payment_date as date),
                cast(source_payments.amount as decimal(18, 2))
            order by source_payments.payment_id
        ) as occurrence
    from source_payments
    inner join {{ ref('bv_invoice_master') }} as master
        on source_payments.invoice_hk = master.invoice_hk
),

master_payments as (
    select
        master_invoice_hk,
        master_invoice_no,
        payment_date,
        amount,
        coalesce(
            max(case when source = 'v1' then payment_id end),
            max(payment_id)
        ) as payment_id
    from numbered_payments
    group by
        master_invoice_hk,
        master_invoice_no,
        payment_date,
        amount,
        occurrence
),

invoice_contract as (
    select
        invoice_master.master_invoice_hk,
        contract_master.master_contract_no
    from {{ ref('link_contract_invoice') }} as link
    inner join {{ ref('bv_invoice_master') }} as invoice_master
        on link.invoice_hk = invoice_master.invoice_hk
    inner join {{ ref('bv_contract_master') }} as contract_master
        on link.contract_hk = contract_master.contract_hk
    qualify
        row_number() over (
            partition by invoice_master.master_invoice_hk
            order by link.load_datetime desc
        ) = 1
)

select
    master_payments.payment_id,
    master_payments.master_invoice_no as invoice_no,
    invoice_contract.master_contract_no as contract_no,
    master_payments.payment_date,
    master_payments.amount
from master_payments
inner join invoice_contract
    on master_payments.master_invoice_hk = invoice_contract.master_invoice_hk
