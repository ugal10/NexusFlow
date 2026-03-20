-- stage customers: union all 3 batches
-- batch_2 is missing customer_id - resolved via email match to batch_1
with batch_1 as (
    select
        customer_id,
        company_name,
        industry,
        region,
        country,
        city,
        signup_date,
        account_owner,
        status,
        email,
        phone,
        employee_count,
        annual_revenue_usd,
        notes,
        null as account_tier,
        _batch_id,
        _loaded_at
    from raw.batch_1_customers
),

batch_2 as (
    -- no customer_id in batch_2 - resolve via email join to batch_1
    select
        b1.customer_id,
        b2.company_name,
        b2.industry,
        b2.region,
        b2.country,
        b2.city,
        b2.signup_date,
        b2.account_owner,
        b2.status,
        b2.email,
        b2.phone,
        b2.employee_count,
        b2.annual_revenue_usd,
        b2.notes,
        b2.account_tier,
        b2._batch_id,
        b2._loaded_at
    from raw.batch_2_customers b2
    left join raw.batch_1_customers b1 on b2.email = b1.email
),

batch_3 as (
    select
        customer_id,
        company_name,
        industry,
        region,
        country,
        city,
        signup_date,
        account_owner,
        status,
        email,
        phone,
        employee_count,
        annual_revenue_usd,
        notes,
        null as account_tier,
        _batch_id,
        _loaded_at
    from raw.batch_3_customers
),

all_batches as (
    select * from batch_1
    union all
    select * from batch_2
    union all
    select * from batch_3
),

cleaned as (
    select
        customer_id,
        company_name,
        industry,
        upper(trim(region))             as region,
        country,
        city,
        signup_date::date               as signup_date,
        account_owner,
        lower(trim(status))             as status,
        email,
        phone,
        employee_count::int             as employee_count,
        annual_revenue_usd::numeric     as annual_revenue_usd,
        notes,
        account_tier,
        _batch_id,
        _loaded_at
    from all_batches
    where customer_id is not null
)

select * from cleaned