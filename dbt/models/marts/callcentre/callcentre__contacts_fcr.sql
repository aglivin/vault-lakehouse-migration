select
    {{ month_trunc('contact_date') }} as contact_month,
    channel,
    reason,
    cast(count(*) as integer) as contact_count,
    cast(
        sum(case when is_resolved_first_contact then 1 else 0 end) as integer
    ) as resolved_first_contact_count,
    cast(
        sum(case when is_resolved_first_contact then 1 else 0 end)
        * 1.0 / count(*)
        as decimal(9, 4)
    ) as fcr_rate
from {{ ref('fct_contact') }}
group by 1, 2, 3
