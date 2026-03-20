-- stage plans: use batch_3 as most current
-- actual columns differ from spec: no tier/overage_rate, has billing_model/api_limit instead
with latest as (
    select * from raw.batch_3_plans
),

cleaned as (
    select
        plan_id,
        plan_name,
        base_price::numeric             as base_price,
        billing_model,
        api_limit::int                  as api_limit,
        storage_gb::int                 as storage_gb,
        features,
        effective_date::date            as effective_date,
        case 
            when lower(trim(is_active)) = 'true' then true 
            else false 
        end                             as is_active,
        _batch_id,
        _loaded_at
    from latest
    where plan_id is not null
)

select * from cleaned