with spine as (
    {{ dbt_utils.date_spine(
        datepart='day',
        start_date="cast('2025-01-01' as date)",
        end_date="cast('2028-01-01' as date)"
    ) }}
)

select
    cast(date_day as date) as date_day,
    extract(year from date_day) as year_no,
    extract(quarter from date_day) as quarter_no,
    extract(month from date_day) as month_no,
    {{ vdwh.month_trunc('cast(date_day as date)') }} as month_start
from spine
