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
        case when dbt_valid_to is null then true else false end  as is_current,
        -- proper surrogate key: customer_id + batch combination
        dbt_scd_id                                              as customer_sk
    from snapshot
)

select * from current_customers