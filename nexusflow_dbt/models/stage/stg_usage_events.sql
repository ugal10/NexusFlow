-- stage usage events: union all 3 batches + late arriving january events from batch 3
with all_batches as (
    select * from raw.batch_1_usage_events
    union all
    select * from raw.batch_2_usage_events
    union all
    select * from raw.batch_3_usage_events
    union all
    -- late arriving january events loaded in batch 3
    select * from raw.batch_3_late_usage_jan
),

cleaned as (
    select
        customer_id,
        event_date::date                as event_date,
        lower(trim(metric_name))        as metric_name,
        quantity::numeric               as quantity,
        unit,
        _batch_id,
        _loaded_at
    from all_batches
    where customer_id is not null
)

select * from cleaned