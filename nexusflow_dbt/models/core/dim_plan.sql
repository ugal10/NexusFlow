-- dim_plan: reference data from stage, one row per plan
select
    plan_id,
    plan_name,
    base_price,
    billing_model,
    api_limit,
    storage_gb,
    features,
    effective_date,
    is_active
from {{ ref('stg_plans') }}