select
    a.customer_no,
    a.valid_from,
    a.valid_to,
    b.valid_from as other_valid_from,
    b.valid_to as other_valid_to
from {{ ref('dim_customer') }} as a
inner join {{ ref('dim_customer') }} as b
    on
        a.customer_no = b.customer_no
        and a.valid_from < b.valid_to
        and b.valid_from < a.valid_to
        and a.valid_from <> b.valid_from
