with vault_load_date as (
    select cast(max(load_datetime) as date) as load_date
    from {{ ref('hub_invoice') }}
),

mart_totals as (
    select
        cast(count(distinct invoice_no) as decimal(18, 2)) as invoice_count,
        cast(sum(net_amount) as decimal(18, 2)) as invoiced_net_total
    from {{ ref('fct_invoice_line') }}
)

select
    vault_load_date.load_date,
    expected_totals.metric,
    expected_totals.value as expected_value,
    case expected_totals.metric
        when 'invoice_count' then mart_totals.invoice_count
        else mart_totals.invoiced_net_total
    end as mart_value
from vault_load_date
cross join mart_totals
inner join {{ ref('expected_totals') }} as expected_totals
    on vault_load_date.load_date = expected_totals.load_date
where expected_totals.metric in ('invoice_count', 'invoiced_net_total')
order by expected_totals.metric
