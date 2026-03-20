-- mart_support: support health metrics by region and priority
with tickets as (
    select * from {{ ref('stg_support_tickets') }}
),

customers as (
    select customer_id, region
    from {{ ref('dim_customer') }}
    where is_current = true
)

select
    date_trunc('month', t.created_at)::date     as month,
    c.region,
    t.priority,
    t.channel,
    count(distinct t.ticket_id)                 as total_tickets,
    count(distinct t.customer_id)               as customers_with_tickets,
    avg(t.resolution_hours)                     as avg_resolution_hours,
    avg(t.satisfaction_score)                   as avg_satisfaction_score,
    count(case when t.resolved_at is not null 
        then 1 end)                             as resolved_tickets
from tickets t
left join customers c on t.customer_id = c.customer_id
group by 1, 2, 3, 4
order by 1, 2, 3