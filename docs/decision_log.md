# Decision Log — NexusFlow Data Platform

## How to Read This Log
Each decision documents: the options considered, the choice made, and the rationale. Rejected alternatives are explicitly noted.

---

## 1. Metric Definitions

### MRR Definition
**Conflict:** Finance, Product, and Sales teams all define MRR differently.

| Team | Definition |
|------|-----------|
| Finance (Sarah Chen) | Active subscriptions only, recognized on invoice date |
| Product (Marcus Rivera) | Subscription base + trailing 3-month average overage, on effective date |
| Sales (Jake Torres) | Any MRR increase including overage growth |

**Decision:** Finance definition — active subscriptions only, invoice date recognition.

**Rationale:** Board reporting requires consistency and predictability. Overage revenue is volatile and distorts month-over-month trending. Invoice date recognition aligns with standard SaaS accounting practices (ASC 606).

**Rejected:** Product's trailing overage inclusion — adds complexity and makes MRR harder to reconcile with invoices. Sales definition conflates MRR with total revenue.

---

### Churn MRR Definition
**Conflict:** Finance excludes downgrades from churn. Product includes "silent churn." Sales says a customer is never churned if they have any active subscription.

**Decision:** Finance definition — full cancellations only = churn. Downgrades = contraction, tracked separately in `fct_mrr_movements`.

**Rationale:** Industry standard (Bessemer, OpenView SaaS benchmarks) separates churn from contraction. Mixing them overstates churn and understates expansion metrics.

**Rejected:** Product's silent churn (zero usage for 90 days) — this is an engagement metric, not a revenue metric. Tracked separately in `mart_usage`. Sales definition — ignoring contraction hides revenue risk.

---

### NRR Definition
**Conflict:** Finance excludes contraction. Product includes contraction and reactivation.

**Decision:** Product definition — (Starting + Expansion - Contraction - Churn) / Starting.

**Rationale:** NRR excluding contraction overstates retention and gives a misleading picture of revenue health. The more conservative Product definition is closer to how investors and analysts calculate NRR. Reactivation is included as it represents real recovered revenue.

**Rejected:** Finance definition — excluding contraction flatters the metric. Sales has no NRR definition.

---

### Customer Count
**Conflict:** Finance includes free tier in counts. Sales excludes free tier.

**Decision:** Finance definition — include free tier in customer counts, exclude from revenue metrics.

**Rationale:** Free tier customers are part of the conversion funnel. Excluding them hides top-of-funnel health. Revenue metrics (MRR, NRR) already filter to paid plans naturally.

**Rejected:** Sales definition — paid-only counts are useful for revenue analysis but should be a filter, not the default.

---

## 2. Architecture Decisions

### Layered Architecture: raw → stage → core → mart
**Decision:** Four-layer architecture.

**Rationale:** Each layer has a single responsibility. Raw preserves source data exactly. Stage normalizes and cleans. Core models business entities. Mart serves specific analytical use cases. This makes debugging and maintenance straightforward — issues are isolated to a single layer.

**Rejected:** Single-layer approach (direct from CSV to analytics) — no auditability, no reusability, brittle to source changes.

---

### dbt for Transformations
**Decision:** dbt Core for all transformations from stage onwards.

**Rationale:** Built-in lineage, testing, documentation, and modularity. `ref()` ensures correct build order. Tests catch data quality issues automatically.

**Rejected:** Pure SQL scripts — no dependency management, no testing framework, harder to maintain.

---

### SCD Type 2 for dim_customer via dbt Snapshots
**Decision:** dbt snapshot with `check` strategy on status, region, account_tier, email, company_name.

**Rationale:** Customer status changes over time (8 customers changed status between batch 1 and batch 3). SCD2 preserves history for accurate point-in-time analysis. dbt snapshots handle this natively with `dbt_valid_from` / `dbt_valid_to`.

**Rejected:** SCD Type 1 (overwrite) — loses history of reactivations and status changes. SCD Type 3 (add column) — too rigid, doesn't scale to multiple changes.

---

### Python ETL for Raw Loading
**Decision:** Python script (`etl/load_raw.py`) using pandas + psycopg2.

**Rationale:** Full control over batch metadata, idempotency, sentinel value handling, and error reporting. Runs independently of dbt.

**Rejected:** dbt seeds — not designed for large evolving datasets. No batch metadata support.

---

## 3. Data Quality Decisions

### Batch 2 Missing customer_id
**Issue:** `batch_2_customers` has no `customer_id` column — different schema from batches 1 and 3.

**Decision:** Resolve customer_id via email join to batch_1_customers. 500/500 customers matched successfully.

**Rationale:** Email is a stable, unique identifier. 100% match rate validates the approach.

**Risk:** If a customer changes their email between batches, they would fail to match. Monitoring added via not_null test on customer_id in stg_customers.

---

### batch_3_adjustments Row Count Drop
**Issue:** batch_2_adjustments has 180 rows, batch_3_adjustments has 120 rows — a 33% drop.

**Possible explanations:** Reversals processed in batch 3 reduce net adjustments. Some batch 2 adjustments corrected via corrections.csv. Data extract scope changed.

**Decision:** Load both batches as-is. Flag for investigation in next sprint. The corrections.csv table (60 rows) likely explains some of this discrepancy.

---

### Corrections Table Strategy
**Issue:** batch_3 introduces a `corrections` table with patches to prior batch data.

**Decision:** Corrections are visible in the raw layer but not yet applied in stage/core. This is documented as a known limitation. Full implementation would require a corrections-application step between raw and stage.

**Rationale:** Time constraint. The corrections table schema (entity_type, entity_id, field_corrected, old_value, new_value) is designed for a generic patch mechanism that requires careful implementation to avoid double-applying corrections.

---

## 4. Access Control Decisions

### Row Level Security at Database Layer
**Decision:** PostgreSQL RLS policies on mart tables, enforced via `user_region_map` lookup table.

**Rationale:** Security enforced at the data layer means it cannot be bypassed by any application or query tool. Regional managers see only their region's data regardless of how they connect.

**Rejected:** Application-layer filtering only — can be bypassed if users connect directly to the database.

---