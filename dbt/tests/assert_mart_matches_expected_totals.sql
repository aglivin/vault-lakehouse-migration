with vault_load_date as (
    select cast(max(load_datetime) as date) as load_date
    from {{ ref('hub_invoice') }}
),

mart_totals as (
    select
        'invoiced_net_total' as metric,
        cast(sum(net_amount) as decimal(18, 2)) as mart_value
    from {{ ref('fct_invoice_line') }}
    union all
    select
        'invoice_count' as metric,
        cast(count(distinct invoice_no) as decimal(18, 2)) as mart_value
    from {{ ref('fct_invoice_line') }}
),

expected as (
    select
        expected_totals.metric,
        expected_totals.value as expected_value
    from {{ ref('expected_totals') }} as expected_totals
    inner join vault_load_date
        on expected_totals.load_date = vault_load_date.load_date
    where expected_totals.metric in ('invoiced_net_total', 'invoice_count')
)

select
    expected.metric,
    expected.expected_value,
    mart_totals.mart_value
from expected
left join mart_totals
    on expected.metric = mart_totals.metric
where mart_totals.mart_value is null
    or mart_totals.mart_value != expected.expected_value
