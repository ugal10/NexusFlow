-- mart_nrr: net revenue retention by batch and region
-- formula: (starting + expansion - contraction - churn) / starting
-- per product team definition (marcus rivera) - includes contraction
-- more conservative and accurate than finance definition
-- see decision_log.md for rationale
with movements as (
    select * from {{ ref('fct_mrr_movements') }}
),

batch_movements as (
    select
        batch_id,
        region,
        sum(case when movement_type = 'new' then current_mrr else 0 end)          as new_mrr,
        sum(case when movement_type = 'expansion' then mrr_change else 0 end)      as expansion_mrr,
        sum(case when movement_type = 'contraction' then abs(mrr_change) else 0 end) as contraction_mrr,
        sum(case when movement_type = 'churn' then abs(mrr_change) else 0 end)     as churned_mrr
    from movements
    group by 1, 2
),

-- get starting mrr from previous batch
starting_mrr as (
    select
        _batch_id + 1                       as batch_id,
        region,
        sum(mrr)                            as starting_mrr
    from {{ ref('fct_subscriptions') }}
    where status = 'active'
    group by 1, 2
)

select
    bm.batch_id,
    bm.region,
    coalesce(sm.starting_mrr, 0)            as starting_mrr,
    bm.expansion_mrr,
    bm.contraction_mrr,
    bm.churned_mrr,
    -- nrr calculation
    case
        when coalesce(sm.starting_mrr, 0) = 0 then null
        else round(
            (sm.starting_mrr + bm.expansion_mrr - bm.contraction_mrr - bm.churned_mrr)
            / sm.starting_mrr * 100
        , 2)
    end                                     as nrr_pct
from batch_movements bm
left join starting_mrr sm
    on bm.batch_id = sm.batch_id
    and bm.region = sm.region
order by bm.batch_id, bm.region