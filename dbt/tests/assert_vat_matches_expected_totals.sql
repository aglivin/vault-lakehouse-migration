with vault_load_date as (
    select cast(max(load_datetime) as date) as load_date
    from {{ ref('hub_invoice') }}
),

mart_vat as (
    select cast(sum(vat_amount) as decimal(18, 2)) as mart_value
    from {{ ref('tax__vat_by_invoice') }}
)

select
    expected_totals.value as expected_value,
    mart_vat.mart_value
from vault_load_date
cross join mart_vat
left join {{ ref('expected_totals') }} as expected_totals
    on vault_load_date.load_date = expected_totals.load_date
        and expected_totals.metric = 'vat_total'
where expected_totals.value is null
    or mart_vat.mart_value is null
    or mart_vat.mart_value != expected_totals.value
