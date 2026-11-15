select
    hub.tariff_code,
    sat.commodity,
    sat.name,
    cast(sat.price_per_kwh as decimal(18, 4)) as price_per_kwh,
    cast(sat.base_fee_month as decimal(18, 2)) as base_fee_month,
    cast(sat.valid_from as date) as valid_from
from {{ ref('hub_tariff') }} as hub
inner join {{ ref('sat_tariff_details_billing_v1') }} as sat
    on hub.tariff_hk = sat.tariff_hk
qualify
    row_number() over (
        partition by hub.tariff_hk order by sat.load_datetime desc
    ) = 1
