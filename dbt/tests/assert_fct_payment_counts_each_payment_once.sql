{{ config(tags=['cross_layer']) }}

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

numbered as (
    select
        master.master_invoice_hk,
        source_payments.source,
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

payments as (
    select
        master_invoice_hk,
        payment_date,
        amount,
        occurrence,
        count(*) as source_rows
    from numbered
    group by master_invoice_hk, payment_date, amount, occurrence
),

expected as (
    select
        count(*) as expected_rows,
        max(source_rows) as max_source_rows
    from payments
)

select
    expected.expected_rows,
    (select count(*) from {{ ref('fct_payment') }}) as actual_rows
from expected
where
    expected.expected_rows <> (select count(*) from {{ ref('fct_payment') }})
    or (
        exists (select 1 from {{ ref('nhl_payment_billing_v2') }})
        and expected.max_source_rows < 2
    )
