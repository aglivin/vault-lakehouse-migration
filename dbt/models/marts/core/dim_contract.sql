with contract_rows as (
    select
        contract_hk,
        load_datetime,
        tariff_code,
        start_date,
        end_date,
        status
    from {{ ref('sat_contract_details_billing_v1') }}
    union all
    select
        contract_hk,
        load_datetime,
        product_code as tariff_code,
        valid_from as start_date,
        valid_to as end_date,
        agreement_status as status
    from {{ ref('sat_contract_details_billing_v2') }}
),

latest_contract as (
    select
        master.master_contract_hk,
        master.master_contract_no,
        contract_rows.tariff_code,
        contract_rows.start_date,
        contract_rows.end_date,
        contract_rows.status
    from contract_rows
    inner join {{ ref('bv_contract_master') }} as master
        on contract_rows.contract_hk = master.contract_hk
    qualify
        row_number() over (
            partition by master.master_contract_hk
            order by contract_rows.load_datetime desc
        ) = 1
),

contract_customer as (
    select
        contract_master.master_contract_hk,
        customer_master.master_customer_no
    from {{ ref('link_customer_contract') }} as link
    inner join {{ ref('bv_contract_master') }} as contract_master
        on link.contract_hk = contract_master.contract_hk
    inner join {{ ref('bv_customer_master') }} as customer_master
        on link.customer_hk = customer_master.customer_hk
    qualify
        row_number() over (
            partition by contract_master.master_contract_hk
            order by link.load_datetime desc
        ) = 1
),

contract_status as (
    select
        master.master_contract_hk,
        sts.status
    from {{ ref('sts_contract') }} as sts
    inner join {{ ref('bv_contract_master') }} as master
        on sts.contract_hk = master.contract_hk
    qualify
        row_number() over (
            partition by master.master_contract_hk
            order by sts.load_datetime desc
        ) = 1
),

tariff_master as (
    select
        hub_tariff.tariff_code,
        bv_tariff_master.master_tariff_no
    from {{ ref('hub_tariff') }} as hub_tariff
    inner join {{ ref('bv_tariff_master') }} as bv_tariff_master
        on hub_tariff.tariff_hk = bv_tariff_master.tariff_hk
)

select
    latest_contract.master_contract_no as contract_no,
    contract_customer.master_customer_no as customer_no,
    tariff_master.master_tariff_no as tariff_code,
    cast(latest_contract.start_date as date) as start_date,
    cast(latest_contract.end_date as date) as end_date,
    lower(latest_contract.status) as status,
    coalesce(contract_status.status = 'D', false) as is_deleted
from latest_contract
inner join contract_customer
    on latest_contract.master_contract_hk = contract_customer.master_contract_hk
left join tariff_master
    on latest_contract.tariff_code = tariff_master.tariff_code
left join contract_status
    on latest_contract.master_contract_hk = contract_status.master_contract_hk
