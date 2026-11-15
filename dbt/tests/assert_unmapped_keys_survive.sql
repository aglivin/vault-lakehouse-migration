with after_cutover as (
    select
        max(load_datetime)
        >= cast('{{ var("cutover_date") }}' as date) as is_after_cutover
    from {{ ref('hub_invoice') }}
),

v2_only_customers as (
    select
        hub.customer_hk,
        hub.customer_no
    from {{ ref('hub_customer') }} as hub
    where
        hub.load_datetime >= cast('{{ var("cutover_date") }}' as date)
        and not exists (
            select 1
            from {{ ref('sal_customer') }} as sal
            where sal.customer_v2_hk = hub.customer_hk
        )
),

non_migrated_contract_invoices as (
    select distinct hub_invoice.invoice_no
    from {{ ref('hub_contract') }} as hub_contract
    inner join {{ ref('link_contract_invoice') }} as link_contract_invoice
        on hub_contract.contract_hk = link_contract_invoice.contract_hk
    inner join {{ ref('hub_invoice') }} as hub_invoice
        on link_contract_invoice.invoice_hk = hub_invoice.invoice_hk
    where
        hub_contract.load_datetime < cast('{{ var("cutover_date") }}' as date)
        and not exists (
            select 1
            from {{ ref('sal_contract') }} as sal
            where sal.contract_hk = hub_contract.contract_hk
        )
)

select
    v2_only_customers.customer_no as business_key,
    'v2-only customer is not its own master' as failure
from v2_only_customers
left join {{ ref('bv_customer_master') }} as master
    on v2_only_customers.customer_hk = master.customer_hk
where
    master.master_customer_hk is null
    or master.master_customer_hk != v2_only_customers.customer_hk

union all

select
    non_migrated_contract_invoices.invoice_no as business_key,
    'invoice of non-migrated contract missing in fct_invoice_line' as failure
from non_migrated_contract_invoices
where
    not exists (
        select 1
        from {{ ref('fct_invoice_line') }} as fct
        where fct.invoice_no = non_migrated_contract_invoices.invoice_no
    )

union all

select
    cast(null as string) as business_key,
    'no v2-only customer after cutover' as failure
from after_cutover
where
    after_cutover.is_after_cutover
    and (select count(*) from v2_only_customers) = 0

union all

select
    cast(null as string) as business_key,
    'no invoice of a non-migrated contract after cutover' as failure
from after_cutover
where
    after_cutover.is_after_cutover
    and (select count(*) from non_migrated_contract_invoices) = 0
