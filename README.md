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

---

## Approach & Design Decisions by Phase

### Phase 1 — Raw Ingestion (`etl/load_raw.py`)

**Drop and recreate tables on every run**
Simplest idempotency strategy for a raw layer — if the pipeline runs twice, the result is identical. Alternative would be truncate+insert or upsert, but for raw data where we want an exact snapshot of the CSV, full reload is correct.

**Store all columns as TEXT**
Raw layer should never transform. If we cast to numeric and the source sends `"N/A"`, the load fails. TEXT preserves everything exactly as it came in. Type casting happens in stage where we have control.

**Add `_batch_id`, `_loaded_at`, `_filename` metadata**
Without batch metadata we can't trace a row back to its source. This enables debugging, reconciliation, and incremental logic downstream.

**Replace sentinel values at load time**
`-`, `N/A`, empty strings are nulls in disguise. Replacing them at the earliest point means every downstream layer gets clean nulls consistently.

**Separate folder per batch**
Later batches introduce new files. A flat folder structure would mix batch files together. Separate folders make batch identity explicit and support evolving schemas gracefully.

---

### Phase 2 — Data Profiling (before writing any transforms)

**Inspect actual column names before writing SQL**
The spec described columns like `mrr_amount`, `line_type`, `tier`, `source_system` — none of which actually existed. Running column inspection queries first saved significant rework. Every model was designed from actual data, not the spec.

**Check distinct values for key categorical columns**
We checked `status`, `region`, and other categoricals to find real values before writing `accepted_values` tests. This is how we found status values like `trial`, `expired`, `suspended` that weren't documented.

**Check ID formats across all batches**
We verified all 3 batches use `CUST-XXX` format — but more importantly discovered batch_2 had no `customer_id` column at all. Profiling this early meant we could design the fix before building the stage model.

**Compare row counts across batches**
We found `batch_3_adjustments` dropped from 180 to 120 rows. Catching anomalies at profiling time means they go into the decision log as documented findings rather than silent data quality issues.

---

### Phase 3 — Stage Layer

**Views, not tables**
Stage models are just cleaning and renaming — no aggregation. Views are always current, cost no storage, and rebuild instantly.

**Union all batches in stage, not in raw**
Raw preserves exact source structure. Unioning is a transformation — it belongs in stage. This keeps each layer's responsibility clean.

**Resolve batch_2 customer_id via email join**
Batch_2 had no customer_id — a real data quality issue. Email was the most reliable stable identifier available. We verified 500/500 match rate before committing to this approach. Company_name was considered but rejected due to typo/format risk.

**Normalize status to lowercase, region to uppercase**
Inconsistent casing breaks GROUP BY and WHERE clauses silently. Normalizing in stage means every downstream model gets consistent values regardless of source system behavior.

**Include late_usage_jan in stg_usage_events**
Late-arriving January events are real January data — excluding them would undercount January usage. Unioning them into the stage model is the correct approach.

**Corrections loaded to raw but not applied in stage**
The corrections table has a generic patch structure — blindly applying it could overwrite valid data. Some apparent errors are actually valid business records. We documented this as a known limitation rather than implementing it incorrectly.

---

### Phase 4 — Core Layer (Star Schema)

**SCD Type 2 for dim_customer via dbt snapshots**
We found 8 customers changed status between batch 1 and batch 3. SCD1 (overwrite) would lose this history. SCD2 preserves it with `dbt_valid_from`/`dbt_valid_to` for point-in-time analysis.

**`check` strategy on specific columns, not `timestamp`**
The data has no reliable `updated_at` column. The `check` strategy compares specific column values between runs and creates a new snapshot record when any change. We chose `status`, `region`, `account_tier`, `email`, `company_name` — the columns most likely to change meaningfully.

**fct_mrr_movements using full outer join between batches**
We need to capture all movement types including churn (customer in batch N but not N+1) and new (customer in N+1 but not N). A regular join would miss these. Full outer join is the only correct approach for MRR movement analysis.

**dim_date as a generated date spine**
Date dimensions should never depend on transactional data — if no events happened on a date, it shouldn't be missing from the dimension. `generate_series` creates a complete gap-free spine regardless of what's in the fact tables.

**Enrich fact tables with region at core layer**
Region is needed for filtering in every mart model. Joining to dim_customer in every mart query would be repetitive and slower. Adding region to facts at core makes mart models simpler and more performant.

---

### Phase 5 — Mart Layer

**Canonical metric definitions from Finance for MRR/Churn, Product for NRR**
We read all three business rules documents and found genuine conflicts. Finance's MRR definition (subscriptions only, invoice date) is the industry standard for board reporting. Product's NRR definition (including contraction) is more conservative and accurate. Every rejected alternative is documented in `docs/decision_log.md`.

**Comments in mart models referencing decision_log.md**
When someone reads `mart_mrr.sql` in 6 months they shouldn't have to guess why overage is excluded. The comment makes the rationale immediately traceable.

---

### Phase 6 — Data Quality & Testing

**Schema tests + custom data tests**
Schema tests (not_null, unique, accepted_values) catch structural integrity issues automatically on every `dbt test` run. We added them to every key column across all layers — 44 tests total.

**accepted_values tests on status and region columns**
These are the columns most likely to get unexpected values as the source system evolves. If a new status like `paused` appears, the test fails and alerts us immediately rather than silently propagating.

**not_null tests on foreign keys**
A null customer_id in fct_subscriptions means orphaned data that can't be attributed to any customer. These tests ensure referential integrity across dbt models.

---

### Phase 7 — Access Control

**RLS at the database layer, not application layer**
Application-layer filtering can be bypassed if a user connects directly via DBeaver or psql. Database-layer RLS cannot be bypassed regardless of how the user connects.

**`user_region_map` lookup table for RLS policies**
Hardcoding region values in RLS policies would require ALTER POLICY every time a new manager is added. A lookup table means adding a new regional manager is just an INSERT — no DDL changes needed.

**Separate roles for admin, analyst, viewer, regional_manager**
Principle of least privilege. Each role gets exactly the access it needs — no more.

---

### Known Gaps & How We'd Address Them

**Timezone normalization**
We cast timestamps but didn't normalize to UTC. In production: `timestamp AT TIME ZONE 'UTC'` in every stage model, with a documented assumption about each source system's timezone.

**Corrections application**
Loaded to raw, not applied downstream. In production: a corrections-application CTE in each stage model that checks `batch_3_corrections` for patches and applies them before the cleaned output.

**Deduplication of late_usage_jan**
Unioned but not deduplicated against original January events. In production: `ROW_NUMBER() OVER (PARTITION BY event_id ORDER BY _batch_id DESC)` dedup step in `stg_usage_events`.

**Incremental models**
All models are full refresh. In production: `fct_invoices`, `fct_payments`, and `fct_usage_events` would be incremental with a watermark on `created_at` or `event_date`.

---
## Contact
Built as part of NexusFlow Senior Data Engineer take-home exercise.