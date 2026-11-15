with touched as (
    select distinct
        customer_no,
        _load_date as load_date
    from {{ source('crm_v1', 'crm_v1__customer_phones') }}
    {% if var('load_date') %}
        where _load_date = cast('{{ var("load_date") }}' as date)
    {% endif %}
),

history as (
    select
        touched.load_date,
        phones.customer_no,
        phones.phone_type,
        phones.phone_number,
        phones.op,
        phones._record_source,
        row_number() over (
            partition by touched.load_date, phones.customer_no, phones.phone_type
            order by phones._load_date desc
        ) as recency
    from touched
    inner join {{ source('crm_v1', 'crm_v1__customer_phones') }} as phones
        on touched.customer_no = phones.customer_no
            and phones._load_date <= touched.load_date
),

active_set as (
    select
        customer_no,
        phone_type,
        phone_number,
        op,
        load_date as load_datetime,
        _record_source as record_source
    from history
    where recency = 1
        and op <> 'D'
)

select
    customer_no,
    phone_type,
    phone_number,
    op,
    load_datetime,
    record_source,
    {{ automate_dv.hash('customer_no', 'customer_hk') }},
    {{ automate_dv.hash(['phone_type', 'phone_number'], 'phone_hashdiff', is_hashdiff=true) }}
from active_set
