# Architecture Documentation — NexusFlow Data Platform

## Overview
A four-layer data warehouse built on PostgreSQL + dbt, with a Python ETL ingestion layer and Streamlit analytics dashboard.

## System Architecture
```
CSV Exports (3 monthly batches)
          │
          ▼
┌─────────────────────┐
│   Python ETL        │  etl/load_raw.py
│   load_raw.py       │  - reads all CSVs
│                     │  - adds batch metadata
│                     │  - idempotent (drop+recreate)
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│   RAW LAYER         │  schema: raw
│   30 tables         │  - one table per file per batch
│                     │  - never modified after load
│                     │  - _batch_id, _loaded_at, _filename
└─────────┬───────────┘
          │  dbt
          ▼
┌─────────────────────┐
│   STAGE LAYER       │  schema: raw_stage (views)
│   9 models          │  - unions batches
│                     │  - normalizes casing, nulls
│                     │  - resolves customer IDs
└─────────┬───────────┘
          │  dbt
          ▼
┌─────────────────────┐
│   CORE LAYER        │  schema: raw_core (tables)
│   7 models          │  - star schema
│   + 1 snapshot      │  - SCD2 via dbt snapshot
│                     │  - fact + dimension tables
└─────────┬───────────┘
          │  dbt
          ▼
┌─────────────────────┐
│   MART LAYER        │  schema: raw_mart (tables)
│   5 models          │  - business KPIs
│                     │  - MRR, NRR, churn, usage
│                     │  - RLS enforced here
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│   STREAMLIT         │  dashboard/app.py
│   DASHBOARD         │  - KPI charts
│                     │  - region filters
│                     │  - batch comparison
└─────────────────────┘
```

## Layer Details

### RAW Layer
- **Schema:** `raw`
- **Materialization:** Tables (permanent)
- **Tables:** 30 (8 in batch 1, +2 in batch 2, +4 in batch 3)
- **Key design:** Append-only. Each batch run drops and recreates tables. All columns stored as TEXT except metadata columns.
- **Metadata columns added:**
  - `_batch_id` — integer (1, 2, or 3)
  - `_loaded_at` — timestamp of load
  - `_filename` — source CSV filename

### STAGE Layer
- **Schema:** `raw_stage`
- **Materialization:** Views (always current)
- **Models:** 9
- **Key transformations:**
  - Union all batches per entity
  - Normalize status/region to lowercase/uppercase
  - Cast TEXT columns to proper types (date, numeric, boolean)
  - Replace sentinel values (already handled in ETL)
  - Resolve batch_2 customer_id via email join

### CORE Layer
- **Schema:** `raw_core`
- **Materialization:** Tables
- **Models:** 7 + 1 snapshot

#### Dimensions
| Model | Description | SCD Type |
|-------|-------------|----------|
| dim_customer | Customer master | SCD2 via snapshot |
| dim_plan | Subscription plans | SCD1 (latest batch) |
| dim_date | Date spine 2024 | Static |

#### Facts
| Model | Grain | Key Metric |
|-------|-------|-----------|
| fct_subscriptions | subscription × batch | MRR |
| fct_invoices | invoice line | amount |
| fct_payments | payment transaction | net_amount |
| fct_mrr_movements | customer × batch transition | mrr_change |

#### Snapshot
- `snap_customers` — tracks customer status changes across batches
- Strategy: `check` on status, region, account_tier, email, company_name
- Produces `dbt_valid_from` / `dbt_valid_to` for point-in-time queries

### MART Layer
- **Schema:** `raw_mart`
- **Materialization:** Tables
- **Models:** 5
- **RLS:** Enabled on all mart tables

| Model | Description |
|-------|-------------|
| mart_mrr | MRR by region, plan, batch |
| mart_churn | Churn/expansion movements |
| mart_nrr | Net Revenue Retention % |
| mart_support | Support health metrics |
| mart_usage | Product engagement |

## Data Model (Star Schema)
```
                    dim_date
                       │
dim_customer ──── fct_subscriptions ──── dim_plan
                       │
                  fct_invoices
                       │
                  fct_payments
                       │
               fct_mrr_movements
```

## Access Control

### Roles
| Role | Schema Access | RLS |
|------|--------------|-----|
| nexusflow_admin | All schemas, all operations | Bypasses RLS |
| nexusflow_analyst | stage + core + mart, read only | No RLS |
| nexusflow_viewer | mart only, read only | No RLS |
| nexusflow_regional_manager | mart only, read only | Filtered by region |

### Row Level Security
- Enforced on all mart tables via PostgreSQL RLS policies
- `public.user_region_map` maps usernames to regions
- Regional managers see only rows matching their region
- Superusers and admins bypass RLS

## Known Limitations & Future Work

1. **Corrections not applied** — batch_3 corrections.csv is loaded to raw but not yet applied to stage/core. Requires a generic patch mechanism.
2. **Late-arriving data** — batch_3_late_usage_jan is unioned into stg_usage_events but deduplication against original January data is not fully implemented.
3. **No incremental loading** — all models are full refresh. Production would use incremental models on fact tables.
4. **Single currency** — all amounts assumed USD per Finance team specification.
5. **Dashboard auth** — Streamlit dashboard does not enforce database roles. Production would use session-based auth tied to DB roles.

## Running the Platform
```bash
# 1. load raw data
export PG_PASSWORD=yourpassword
python3 etl/load_raw.py

# 2. run dbt snapshot
cd nexusflow_dbt
dbt snapshot

# 3. run all dbt models
dbt run

# 4. run tests
dbt test

# 5. launch dashboard
cd ../dashboard
streamlit run app.py
```