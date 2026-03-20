-- fct_mrr_movements: tracks mrr changes between batches
-- movement types: new, expansion, contraction, churn, reactivation
with subs as (
    select * from {{ ref('stg_subscriptions') }}
),

-- get mrr per customer per batch
batch_mrr as (
    select
        customer_id,
        _batch_id,
        sum(mrr) as total_mrr
    from subs
    where status = 'active'
    group by customer_id, _batch_id
),

-- compare consecutive batches
mrr_changes as (
    select
        coalesce(curr.customer_id, prev.customer_id) as customer_id,
        coalesce(curr._batch_id, prev._batch_id + 1)  as batch_id,
        prev.total_mrr                                 as previous_mrr,
        curr.total_mrr                                 as current_mrr,
        coalesce(curr.total_mrr, 0) - coalesce(prev.total_mrr, 0) as mrr_change,
        case
            when prev.customer_id is null then 'new'
            when curr.customer_id is null then 'churn'
            when curr.total_mrr > prev.total_mrr then 'expansion'
            when curr.total_mrr < prev.total_mrr then 'contraction'
            else 'retained'
        end as movement_type
    from batch_mrr curr
    full outer join batch_mrr prev
        on curr.customer_id = prev.customer_id
        and curr._batch_id = prev._batch_id + 1
)

select
    mc.customer_id,
    c.region,
    mc.batch_id,
    mc.previous_mrr,
    mc.current_mrr,
    mc.mrr_change,
    mc.movement_type
from mrr_changes mc
left join {{ ref('dim_customer') }} c
    on mc.customer_id = c.customer_id
    and c.is_current = true
where mc.movement_type != 'retained'