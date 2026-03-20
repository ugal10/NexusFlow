-- stage payments: union all 3 batches
with all_batches as (
    select * from raw.batch_1_payments
    union all
    select * from raw.batch_2_payments
    union all
    select * from raw.batch_3_payments
),

cleaned as (
    select
        payment_id,
        invoice_id,
        customer_id,
        amount::numeric                 as amount,
        lower(trim(payment_method))     as payment_method,
        payment_date::timestamp         as payment_date,
        lower(trim(status))             as status,
        transaction_ref,
        processor_fee::numeric          as processor_fee,
        net_amount::numeric             as net_amount,
        _batch_id,
        _loaded_at
    from all_batches
    where payment_id is not null
)

select * from cleaned