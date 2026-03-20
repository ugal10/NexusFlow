-- stage subscriptions: union all 3 batches
-- actual column is mrr not mrr_amount
with all_batches as (
    select * from raw.batch_1_subscriptions
    union all
    select * from raw.batch_2_subscriptions
    union all
    select * from raw.batch_3_subscriptions
),

cleaned as (
    select
        subscription_id,
        customer_id,
        plan_id,
        lower(trim(status))             as status,
        start_date::date                as start_date,
        end_date::date                  as end_date,
        mrr::numeric                    as mrr,
        billing_cycle,
        case 
            when lower(trim(auto_renew)) = 'true' then true 
            else false 
        end                             as auto_renew,
        _batch_id,
        _loaded_at
    from all_batches
    where subscription_id is not null
)

select * from cleaned