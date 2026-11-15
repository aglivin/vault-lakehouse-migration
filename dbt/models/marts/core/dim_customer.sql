with customer_rows as (
    select
        customer_hk,
        load_datetime,
        1 as source_rank,
        first_name,
        last_name,
        email,
        birth_date,
        street,
        city,
        postal_code,
        segment
    from {{ ref('sat_customer_details_crm_v1') }}
    union all
    select
        customer_hk,
        load_datetime,
        0 as source_rank,
        given_name as first_name,  -- noqa: RF04
        family_name as last_name,  -- noqa: RF04
        email_address as email,  -- noqa: RF04
        date_of_birth as birth_date,
        street_line as street,
        town as city,
        zip as postal_code,
        customer_segment as segment
    from {{ ref('sat_customer_details_crm_v2') }}
),

master_rows as (
    select
        master.master_customer_no as customer_no,
        cast(customer_rows.load_datetime as date) as load_date,
        customer_rows.first_name,
        customer_rows.last_name,
        customer_rows.email,
        cast(customer_rows.birth_date as date) as birth_date,
        customer_rows.street,
        customer_rows.city,
        customer_rows.postal_code,
        customer_rows.segment,
        md5(concat_ws(
            '|',
            coalesce(customer_rows.first_name, ''),
            coalesce(customer_rows.last_name, ''),
            coalesce(customer_rows.email, ''),
            coalesce(cast(customer_rows.birth_date as string), ''),
            coalesce(customer_rows.street, ''),
            coalesce(customer_rows.city, ''),
            coalesce(customer_rows.postal_code, ''),
            coalesce(customer_rows.segment, '')
        )) as attributes_hash
    from customer_rows
    inner join {{ ref('bv_customer_master') }} as master
        on customer_rows.customer_hk = master.customer_hk
    qualify
        row_number() over (
            partition by
                master.master_customer_hk,
                cast(customer_rows.load_datetime as date)
            order by
                customer_rows.source_rank asc,
                customer_rows.load_datetime desc
        ) = 1
),

changed as (
    select
        customer_no,
        load_date,
        first_name,
        last_name,
        email,
        birth_date,
        street,
        city,
        postal_code,
        segment,
        attributes_hash,
        lag(attributes_hash)
            over (partition by customer_no order by load_date)
            as previous_hash
    from master_rows
),

versions as (
    select
        customer_no,
        load_date as valid_from,
        first_name,
        last_name,
        email,
        birth_date,
        street,
        city,
        postal_code,
        segment,
        lead(load_date) over (partition by customer_no order by load_date)
            as next_valid_from
    from changed
    where previous_hash is null or previous_hash <> attributes_hash
)

select
    customer_no,
    valid_from,
    first_name,
    last_name,
    email,
    birth_date,
    street,
    city,
    postal_code,
    segment,
    coalesce(next_valid_from, cast('9999-12-31' as date)) as valid_to,
    next_valid_from is null as is_current
from versions
