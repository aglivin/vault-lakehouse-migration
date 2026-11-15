with counts as (
    select
        (select count(*) from {{ ref('nhl_payment_billing_v1') }}) as v1_payments,
        (select count(*) from {{ ref('nhl_payment_billing_v2') }}) as v2_settlements,
        (select count(*) from {{ ref('fct_payment') }}) as fct_payment_rows
)

select
    v1_payments,
    v2_settlements,
    fct_payment_rows,
    v1_payments + v2_settlements - fct_payment_rows as v2_matched_to_v1
from counts
