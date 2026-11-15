select
    'hub' as table_type,
    'hub_customer' as table_name,
    count(*) as row_count
from {{ ref('hub_customer') }}

union all

select
    'hub' as table_type,
    'hub_contract' as table_name,
    count(*) as row_count
from {{ ref('hub_contract') }}

union all

select
    'hub' as table_type,
    'hub_meter' as table_name,
    count(*) as row_count
from {{ ref('hub_meter') }}

union all

select
    'hub' as table_type,
    'hub_invoice' as table_name,
    count(*) as row_count
from {{ ref('hub_invoice') }}

union all

select
    'hub' as table_type,
    'hub_tariff' as table_name,
    count(*) as row_count
from {{ ref('hub_tariff') }}

union all

select
    'link' as table_type,
    'link_customer_contract' as table_name,
    count(*) as row_count
from {{ ref('link_customer_contract') }}

union all

select
    'link' as table_type,
    'link_contract_meter' as table_name,
    count(*) as row_count
from {{ ref('link_contract_meter') }}

union all

select
    'link' as table_type,
    'link_contract_invoice' as table_name,
    count(*) as row_count
from {{ ref('link_contract_invoice') }}

union all

select
    'link' as table_type,
    'link_invoice_tariff' as table_name,
    count(*) as row_count
from {{ ref('link_invoice_tariff') }}

union all

select
    'sat' as table_type,
    'sat_customer_details_crm_v1' as table_name,
    count(*) as row_count
from {{ ref('sat_customer_details_crm_v1') }}

union all

select
    'sat' as table_type,
    'sat_contract_details_billing_v1' as table_name,
    count(*) as row_count
from {{ ref('sat_contract_details_billing_v1') }}

union all

select
    'sat' as table_type,
    'sat_invoice_details_billing_v1' as table_name,
    count(*) as row_count
from {{ ref('sat_invoice_details_billing_v1') }}

union all

select
    'sat' as table_type,
    'sat_invoice_line_billing_v1' as table_name,
    count(*) as row_count
from {{ ref('sat_invoice_line_billing_v1') }}

union all

select
    'sat' as table_type,
    'sat_tariff_details_billing_v1' as table_name,
    count(*) as row_count
from {{ ref('sat_tariff_details_billing_v1') }}

union all

select
    'ma_sat' as table_type,
    'sat_customer_phone_ma' as table_name,
    count(*) as row_count
from {{ ref('sat_customer_phone_ma') }}

union all

select
    'eff_sat' as table_type,
    'eff_sat_customer_contract' as table_name,
    count(*) as row_count
from {{ ref('eff_sat_customer_contract') }}

union all

select
    'sts' as table_type,
    'sts_contract' as table_name,
    count(*) as row_count
from {{ ref('sts_contract') }}
