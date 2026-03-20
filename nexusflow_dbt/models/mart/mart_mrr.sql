-- mart_mrr: monthly mrr summary by region and plan
-- canonical definition: active subscriptions only, recognized at batch level
-- per finance team (sarah chen) decision - see decision_log.md
with fct as (
    select * from {{ ref('fct_subscriptions') }}
),

summary as (
    select
        _batch_id                           as batch_id,
        region,
        plan_name,
        count(distinct customer_id)         as active_customers,
        sum(mrr)                            as total_mrr,
        avg(mrr)                            as avg_mrr_per_customer
    from fct
    where status = 'active'
    group by 1, 2, 3
)

select * from summary
order by batch_id, region, plan_name