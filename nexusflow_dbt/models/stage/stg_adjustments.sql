-- stage adjustments: batch 2 and 3 only (not in batch 1)
with all_batches as (
    select * from raw.batch_2_adjustments
    union all
    select * from raw.batch_3_adjustments
),

cleaned as (
    select
        adjustment_id,
        customer_id,
        invoice_id,
        lower(trim(adjustment_type))    as adjustment_type,
        amount::numeric                 as amount,
        reason,
        effective_date::date            as effective_date,
        created_at::timestamp           as created_at,
        approved_by,
        lower(trim(status))             as status,
        reverses_adjustment_id,
        _batch_id,
        _loaded_at
    from all_batches
    where adjustment_id is not null
)

select * from cleaned