-- fct_subscriptions: one row per subscription per batch
-- captures subscription state at each batch snapshot
with subs as (
    select * from {{ ref('stg_subscriptions') }}
),

customers as (
    select customer_id, region
    from {{ ref('dim_customer') }}
    where is_current = true
),

plans as (
    select plan_id, plan_name, base_price
    from {{ ref('dim_plan') }}
)

select
    s.subscription_id,
    s.customer_id,
    c.region,
    s.plan_id,
    p.plan_name,
    s.status,
    s.start_date,
    s.end_date,
    s.mrr,
    s.billing_cycle,
    s.auto_renew,
    s._batch_id,
    s._loaded_at
from subs s
left join customers c on s.customer_id = c.customer_id
left join plans p on s.plan_id = p.plan_id