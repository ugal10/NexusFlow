-- dim_customer: built from snapshot, one current row per customer
-- includes dbt_valid_from and dbt_valid_to for historical analysis
with snapshot as (
    select * from {{ ref('snap_customers') }}
),

current_customers as (
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
        account_tier,
        dbt_valid_from,
        dbt_valid_to,
        -- flag current record
        case when dbt_valid_to is null then true else false end as is_current,
        dbt_scd_id as customer_sk -- surrogate key
    from snapshot
)

select * from current_customers