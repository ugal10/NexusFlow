-- fct_invoices: one row per invoice, enriched with customer region
with invoices as (
    select * from {{ ref('stg_invoices') }}
),

customers as (
    select customer_id, region
    from {{ ref('dim_customer') }}
    where is_current = true
)

select
    i.invoice_id,
    i.customer_id,
    c.region,
    i.subscription_id,
    i.invoice_date,
    i.due_date,
    i.amount,
    i.currency,
    i.status,
    i.line_items_count,
    i.tax_amount,
    i.total_amount,
    i.period_start,
    i.period_end,
    i.created_at,
    i._batch_id,
    i._loaded_at
from invoices i
left join customers c on i.customer_id = c.customer_id