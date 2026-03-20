-- stage contract amendments: batch 2 and 3 only
with all_batches as (
    select * from raw.batch_2_contract_amendments
    union all
    select * from raw.batch_3_contract_amendments
),

cleaned as (
    select
        amendment_id,
        customer_id,
        subscription_id,
        lower(trim(amendment_type))     as amendment_type,
        old_plan_id,
        new_plan_id,
        old_mrr::numeric                as old_mrr,
        new_mrr::numeric                as new_mrr,
        effective_date::date            as effective_date,
        created_at::timestamp           as created_at,
        reason,
        approved_by,
        _batch_id,
        _loaded_at
    from all_batches
    where amendment_id is not null
)

select * from cleaned