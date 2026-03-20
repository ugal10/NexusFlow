-- stage support tickets: union all 3 batches
with all_batches as (
    select * from raw.batch_1_support_tickets
    union all
    select * from raw.batch_2_support_tickets
    union all
    select * from raw.batch_3_support_tickets
),

cleaned as (
    select
        ticket_id,
        customer_id,
        category,
        lower(trim(priority))           as priority,
        created_at::timestamp           as created_at,
        resolved_at::timestamp          as resolved_at,
        resolution_hours::numeric       as resolution_hours,
        satisfaction_score::numeric     as satisfaction_score,
        agent_name,
        lower(trim(channel))            as channel,
        description,
        _batch_id,
        _loaded_at
    from all_batches
    where ticket_id is not null
)

select * from cleaned