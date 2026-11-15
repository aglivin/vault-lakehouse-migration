with vault_load_date as (
    select cast(max(load_datetime) as date) as load_date
    from {{ ref('hub_invoice') }}
),

required_metrics as (
    select 'invoiced_net_total' as metric
    union all
    select 'invoice_count' as metric
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
)

select
    required_metrics.metric,
    expected_totals.value as expected_value,
    mart_totals.mart_value
from required_metrics
cross join vault_load_date
left join {{ ref('expected_totals') }} as expected_totals
    on required_metrics.metric = expected_totals.metric
        and vault_load_date.load_date = expected_totals.load_date
left join mart_totals
    on required_metrics.metric = mart_totals.metric
where expected_totals.value is null
    or mart_totals.mart_value is null
    or mart_totals.mart_value != expected_totals.value
