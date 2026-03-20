-- mart_usage: product engagement by customer and metric
with usage as (
    select * from {{ ref('stg_usage_events') }}
),

customers as (
    select customer_id, region
    from {{ ref('dim_customer') }}
    where is_current = true
)

select
    date_trunc('month', u.event_date)::date     as month,
    c.region,
    u.metric_name,
    count(distinct u.customer_id)               as active_customers,
    sum(u.quantity)                             as total_quantity,
    avg(u.quantity)                             as avg_quantity_per_customer
from usage u
left join customers c on u.customer_id = c.customer_id
group by 1, 2, 3
order by 1, 2, 3