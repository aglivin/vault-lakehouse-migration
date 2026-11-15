{{ config(tags=['cross_layer']) }}

with changed_in_source as (
    select count(*) as customers
    from (
        select customer_hk
        from {{ ref('sat_customer_details_crm_v1') }}
        group by customer_hk
        having count(*) > 1
    ) as changed
),

versioned_in_dim as (
    select count(*) as customers
    from (
        select customer_no
        from {{ ref('dim_customer') }}
        group by customer_no
        having count(*) > 1
    ) as versioned
)

select changed_in_source.customers
from changed_in_source
cross join versioned_in_dim
where
    (changed_in_source.customers > 0 and versioned_in_dim.customers = 0)
    or not exists (select 1 from {{ ref('dim_customer') }} where is_current)
