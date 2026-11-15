with satellite_rows as (
    select
        master.master_customer_hk,
        sat.load_datetime,
        'crm_v1' as satellite
    from {{ ref('sat_customer_details_crm_v1') }} as sat
    inner join {{ ref('bv_customer_master') }} as master
        on sat.customer_hk = master.customer_hk
    union all
    select
        master.master_customer_hk,
        sat.load_datetime,
        'crm_v2' as satellite
    from {{ ref('sat_customer_details_crm_v2') }} as sat
    inner join {{ ref('bv_customer_master') }} as master
        on sat.customer_hk = master.customer_hk
)

select
    satellite_rows.master_customer_hk as customer_hk,
    as_of_dates.as_of_date,
    max(
        case
            when satellite_rows.satellite = 'crm_v1'
                then satellite_rows.load_datetime
        end
    ) as sat_crm_v1_ldts,
    max(
        case
            when satellite_rows.satellite = 'crm_v2'
                then satellite_rows.load_datetime
        end
    ) as sat_crm_v2_ldts
from satellite_rows
inner join {{ ref('as_of_dates') }} as as_of_dates
    on
        cast(satellite_rows.load_datetime as date)
        <= as_of_dates.as_of_date
group by satellite_rows.master_customer_hk, as_of_dates.as_of_date
