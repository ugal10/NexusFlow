{% snapshot snap_customers %}

{{
    config(
        target_schema='snapshots',
        unique_key='customer_id',
        strategy='check',
        check_cols=['status', 'region', 'account_tier', 'email', 'company_name'],
        invalidate_hard_deletes=False
    )
}}

-- snapshot tracks customer changes across batches
-- using check strategy since we don't have a reliable updated_at column
-- we check the columns most likely to change: status, region, account_tier
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
    _batch_id,
    _loaded_at
from {{ ref('stg_customers') }}

{% endsnapshot %}