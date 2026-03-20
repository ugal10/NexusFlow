# NexusFlow
# NexusFlow Data Platform

A complete data warehouse and analytics platform built for NexusFlow, a B2B SaaS company. Built by a Senior Data Engineer from scratch using PostgreSQL, dbt, Python, and Streamlit.

---

## Architecture
```
CSV Exports (3 monthly batches)
        ↓
Python ETL (etl/load_raw.py)
        ↓
RAW layer (PostgreSQL schema: raw)
        ↓
STAGE layer (dbt views — schema: raw_stage)
        ↓
CORE layer (dbt tables — schema: raw_core)
        ↓
MART layer (dbt tables — schema: raw_mart)
        ↓
Streamlit Dashboard (dashboard/app.py)
```

Full architecture details in `docs/architecture.md`.
Metric decisions and tradeoffs in `docs/decision_log.md`.

---

## Tech Stack

| Component | Tool |
|-----------|------|
| Database | PostgreSQL 18 |
| Transformations | dbt Core 1.11 |
| ETL / Ingestion | Python 3 + pandas + psycopg2 |
| Dashboard | Streamlit |
| Access Control | PostgreSQL roles + Row Level Security |
| Version Control | Git / GitHub |

---

## Project Structure
```
NexusFlow/
├── data/
│   ├── batch_1/          ← 8 CSV files (Jan 2024)
│   ├── batch_2/          ← 10 CSV files (Feb 2024)
│   └── batch_3/          ← 12 CSV files (Mar 2024)
├── etl/
│   └── load_raw.py       ← loads CSVs into raw layer
├── nexusflow_dbt/
│   ├── models/
│   │   ├── stage/        ← 9 staging models (views)
│   │   ├── core/         ← 7 core models + 1 snapshot (tables)
│   │   └── mart/         ← 5 mart models (tables)
│   ├── snapshots/        ← SCD2 customer snapshot
│   └── dbt_project.yml
├── dashboard/
│   └── app.py            ← Streamlit analytics dashboard
├── sql/
│   └── access_control.sql ← roles + RLS policies
├── docs/
│   ├── decision_log.md   ← metric decisions + tradeoffs
│   └── architecture.md   ← full architecture documentation
└── README.md
```

---

## Prerequisites

- PostgreSQL 18
- Python 3.10+
- dbt Core 1.11

Install Python dependencies:
```bash
pip3 install dbt-core dbt-postgres streamlit pandas psycopg2-binary sqlalchemy
```

---

## Setup & Running

### 1. Create the database
```bash
psql -U postgres -c "CREATE DATABASE nexusflow;"
```

### 2. Set environment variable
```bash
export PG_PASSWORD="your_postgres_password"
```

### 3. Load raw data
```bash
cd NexusFlow
python3 etl/load_raw.py
```

Expected output: `30 table(s) loaded.`

### 4. Run dbt snapshot
```bash
cd nexusflow_dbt
dbt snapshot
```

### 5. Run dbt models
```bash
dbt run
```

Expected: 21 models passing across stage, core, mart layers.

### 6. Run dbt tests
```bash
dbt test
```

Expected: 44 tests passing.

### 7. Apply access control
Run `sql/access_control.sql` in your PostgreSQL client (pgAdmin or psql).

### 8. Launch dashboard
```bash
cd ../dashboard
streamlit run app.py
```

Open http://localhost:8501 in your browser.

---

## dbt Models

### Stage Layer (views)
| Model | Description |
|-------|-------------|
| stg_customers | Unions 3 batches, resolves batch_2 missing customer_id via email join |
| stg_subscriptions | Unions 3 batches, normalizes status |
| stg_invoices | Unions 3 batches |
| stg_payments | Unions 3 batches, normalizes payment method |
| stg_plans | Latest batch only (batch 3) |
| stg_usage_events | Unions all batches + late_usage_jan |
| stg_support_tickets | Unions 3 batches |
| stg_adjustments | Batch 2 + 3 only |
| stg_contract_amendments | Batch 2 + 3 only |

### Core Layer (tables)
| Model | Description |
|-------|-------------|
| dim_customer | SCD Type 2 via dbt snapshot |
| dim_plan | Plan reference data |
| dim_date | Date spine 2024 |
| fct_subscriptions | One row per subscription per batch |
| fct_invoices | Invoice transactions with region |
| fct_payments | Payment transactions with region |
| fct_mrr_movements | MRR changes: new, expansion, contraction, churn |

### Mart Layer (tables)
| Model | Description |
|-------|-------------|
| mart_mrr | MRR by region and plan |
| mart_churn | Churn and expansion movements |
| mart_nrr | Net Revenue Retention % |
| mart_usage | Product engagement metrics |
| mart_support | Support health by region |

---

## Access Control

| Role | Access | RLS |
|------|--------|-----|
| nexusflow_admin | All schemas | Bypasses RLS |
| nexusflow_analyst | stage + core + mart (read) | No RLS |
| nexusflow_viewer | mart only (read) | No RLS |
| nexusflow_regional_manager | mart only (read) | Filtered by region |

---

## Key Data Quality Issues Found

1. **batch_2_customers missing customer_id** — resolved via email join to batch_1 (500/500 matched)
2. **batch_3_adjustments row count drop** — 180 → 120 rows, likely due to reversals in batch_3
3. **batch_3_corrections** — loaded to raw layer, not yet applied to stage/core (documented limitation)
4. **Customer status changes** — 8 customers changed status across batches, handled via SCD2

---

## Metric Decisions

See `docs/decision_log.md` for full details. Summary:

| Metric | Chosen Definition | Source |
|--------|------------------|--------|
| MRR | Active subscriptions only, invoice date | Finance (Sarah Chen) |
| Churn MRR | Full cancellations only | Finance (Sarah Chen) |
| NRR | Includes contraction | Product (Marcus Rivera) |
| Customer Count | Include free tier | Finance (Sarah Chen) |

---

## Change Request Responses

### CR-1: Regional Manager Role with Row Level Security
**Status: Implemented**
- PostgreSQL RLS policies on all mart tables
- `public.user_region_map` maps usernames to regions
- Regional managers see only their region's data at the database layer
- Affects all queries — any tool connecting to the DB is automatically filtered
- Company-wide aggregates require a superuser or admin role

### CR-2: NRR by Contract Effective Date
**Status: Impact Analysis**
- Requires adding `effective_date` join to `fct_mrr_movements`
- Retroactive amendments (effective_date < created_at) would require restating historical MRR periods
- Recommended approach: add `amendment_effective_date` as an alternate date key in the fact table
- No need to drop existing invoice_date logic — run both in parallel and let Finance choose

### CR-3: New Partner Referral Source
**Status: Impact Analysis**
- No customer_id in the file — requires fuzzy matching by name or email
- Recommended matching strategy: exact email match first, then company name similarity (pg_trgm extension)
- Non-matches → quarantine table for manual review
- Adds `partner_id` as optional foreign key on `dim_customer`
- Partial matches should never be auto-applied without confidence threshold

---

## Known Limitations

1. Corrections (batch_3) not applied to stage/core layer
2. No incremental dbt models — full refresh only
3. Dashboard does not enforce database roles (uses postgres superuser)
4. Single currency (USD) assumed throughout
5. Late-arriving January data unioned but not deduplicated against original events

---

## Contact
Built as part of NexusFlow Senior Data Engineer take-home exercise.