-- fct_payments: one row per payment transaction
with payments as (
    select * from {{ ref('stg_payments') }}
),

customers as (
    select customer_id, region
    from {{ ref('dim_customer') }}
    where is_current = true
)

select
    p.payment_id,
    p.invoice_id,
    p.customer_id,
    c.region,
    p.amount,
    p.payment_method,
    p.payment_date,
    p.status,
    p.transaction_ref,
    p.processor_fee,
    p.net_amount,
    p._batch_id,
    p._loaded_at
from payments p
left join customers c on p.customer_id = c.customer_id