{{ config(severity='warn') }}

{% set hubs = ['hub_customer', 'hub_contract', 'hub_meter', 'hub_invoice', 'hub_tariff'] %}
{% set built_load_date = "cast('" ~ var('load_date') ~ "' as date)" if var('load_date') else 'cast(null as date)' %}

with loaded as (
    {% for hub in hubs %}
        select max(load_datetime) as last_load_datetime
        from {{ ref(hub) }}
        {% if not loop.last %}union all{% endif %}
    {% endfor %}
)

select
    {{ built_load_date }} as built_load_date,
    max(last_load_datetime) as last_loaded_load_datetime
from loaded
having {{ built_load_date }} < max(last_load_datetime)
