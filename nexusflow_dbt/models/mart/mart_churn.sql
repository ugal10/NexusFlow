-- mart_churn: churn and expansion analysis per batch
-- canonical definition: full cancellations only = churn
-- downgrades = contraction (tracked separately)
-- per finance team decision - see decision_log.md
with movements as (
    select * from {{ ref('fct_mrr_movements') }}
)

select
    batch_id,
    region,
    movement_type,
    count(distinct customer_id)     as customer_count,
    sum(mrr_change)                 as mrr_impact,
    abs(sum(mrr_change))            as abs_mrr_impact
from movements
group by 1, 2, 3
order by batch_id, region, movement_type