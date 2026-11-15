with tariff_rows as (
    select
        tariff_hk,
        load_datetime,
        commodity,
        name,
        price_per_kwh,
        base_fee_month,
        valid_from
    from {{ ref('sat_tariff_details_billing_v1') }}
    union all
    select
        tariff_hk,
        load_datetime,
        commodity,
        product_name as name,  -- noqa: RF04
        unit_price_kwh as price_per_kwh,
        monthly_fee as base_fee_month,
        available_from as valid_from
    from {{ ref('sat_tariff_details_billing_v2') }}
)

select
    master.master_tariff_no as tariff_code,
    tariff_rows.commodity,
    tariff_rows.name,
    cast(tariff_rows.price_per_kwh as decimal(18, 4)) as price_per_kwh,
    cast(tariff_rows.base_fee_month as decimal(18, 2)) as base_fee_month,
    cast(tariff_rows.valid_from as date) as valid_from
from tariff_rows
inner join {{ ref('bv_tariff_master') }} as master
    on tariff_rows.tariff_hk = master.tariff_hk
qualify
    row_number() over (
        partition by master.master_tariff_hk
        order by tariff_rows.load_datetime desc
    ) = 1
