-- stage invoices: union all 3 batches
with all_batches as (
    select * from raw.batch_1_invoices
    union all
    select * from raw.batch_2_invoices
    union all
    select * from raw.batch_3_invoices
),

cleaned as (
    select
        invoice_id,
        customer_id,
        subscription_id,
        invoice_date::date                          as invoice_date,
        due_date::date                              as due_date,
        amount::numeric                             as amount,
        currency,
        lower(trim(status))                         as status,
        line_items_count::int                       as line_items_count,
        tax_amount::numeric                         as tax_amount,
        total_amount::numeric                       as total_amount,
        period_start::date                          as period_start,
        period_end::date                            as period_end,
        created_at::timestamp                       as created_at,
        _batch_id,
        _loaded_at
    from all_batches
    where invoice_id is not null
)

select * from cleaned