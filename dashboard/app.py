import streamlit as st
import pandas as pd
import os
from sqlalchemy import create_engine

# ── page config ──────────────────────────────────────────────
st.set_page_config(
    page_title="NexusFlow Analytics",
    page_icon="🔷",
    layout="wide"
)

# ── db connection ─────────────────────────────────────────────
@st.cache_resource
def get_engine():
    password = os.environ.get("PG_PASSWORD", "")
    return create_engine(f"postgresql://postgres:{password}@localhost:5432/nexusflow")

@st.cache_data(ttl=300)
def run_query(sql):
    engine = get_engine()
    return pd.read_sql(sql, engine)

# ── sidebar filters ───────────────────────────────────────────
st.sidebar.title("🔷 NexusFlow")
st.sidebar.markdown("---")

region_options = ["All"] + ["NA", "EMEA", "APAC"]
selected_region = st.sidebar.selectbox("Region", region_options)

batch_options = [1, 2, 3]
selected_batch = st.sidebar.selectbox("Batch", batch_options, index=2)

# helper to apply region filter
def region_filter(col="region"):
    if selected_region == "All":
        return ""
    return f"where {col} = '{selected_region}'"

def region_and_filter(col="region"):
    if selected_region == "All":
        return ""
    return f"and {col} = '{selected_region}'"

# ── header ────────────────────────────────────────────────────
st.title("NexusFlow Analytics Dashboard")
st.markdown(f"**Batch:** {selected_batch} &nbsp;|&nbsp; **Region:** {selected_region}")
st.markdown("---")

# ── kpi cards ────────────────────────────────────────────────
st.subheader("📊 Key Metrics")

col1, col2, col3, col4 = st.columns(4)

# total mrr
mrr_query = f"""
    select coalesce(sum(total_mrr), 0) as total_mrr
    from raw_mart.mart_mrr
    where batch_id = {selected_batch}
    {region_and_filter()}
"""
mrr_df = run_query(mrr_query)
total_mrr = mrr_df["total_mrr"].iloc[0]

# active customers
customers_query = f"""
    select coalesce(sum(active_customers), 0) as active_customers
    from raw_mart.mart_mrr
    where batch_id = {selected_batch}
    {region_and_filter()}
"""
customers_df = run_query(customers_query)
active_customers = customers_df["active_customers"].iloc[0]

# nrr
nrr_query = f"""
    select coalesce(avg(nrr_pct), 0) as nrr_pct
    from raw_mart.mart_nrr
    where batch_id = {selected_batch}
    {region_and_filter()}
"""
nrr_df = run_query(nrr_query)
nrr_pct = nrr_df["nrr_pct"].iloc[0]

# churn count
churn_query = f"""
    select coalesce(sum(customer_count), 0) as churn_count
    from raw_mart.mart_churn
    where batch_id = {selected_batch}
    and movement_type = 'churn'
    {region_and_filter()}
"""
churn_df = run_query(churn_query)
churn_count = churn_df["churn_count"].iloc[0]

col1.metric("Total MRR", f"${total_mrr:,.0f}")
col2.metric("Active Customers", f"{active_customers:,.0f}")
col3.metric("NRR %", f"{nrr_pct:.1f}%" if nrr_pct else "N/A")
col4.metric("Churned Customers", f"{churn_count:,.0f}")

st.markdown("---")

# ── mrr section ───────────────────────────────────────────────
st.subheader("💰 MRR Analysis")

col_left, col_right = st.columns(2)

# mrr by region over batches
with col_left:
    st.markdown("**MRR by Region (all batches)**")
    mrr_region_query = f"""
        select batch_id, region, sum(total_mrr) as total_mrr
        from raw_mart.mart_mrr
        {region_filter()}
        group by batch_id, region
        order by batch_id, region
    """
    mrr_region_df = run_query(mrr_region_query)
    if not mrr_region_df.empty:
        mrr_pivot = mrr_region_df.pivot(
            index="batch_id", columns="region", values="total_mrr"
        ).fillna(0)
        st.bar_chart(mrr_pivot)

# mrr by plan
with col_right:
    st.markdown("**MRR by Plan**")
    mrr_plan_query = f"""
        select plan_name, sum(total_mrr) as total_mrr
        from raw_mart.mart_mrr
        where batch_id = {selected_batch}
        {region_and_filter()}
        group by plan_name
        order by total_mrr desc
    """
    mrr_plan_df = run_query(mrr_plan_query)
    if not mrr_plan_df.empty:
        st.bar_chart(mrr_plan_df.set_index("plan_name"))

st.markdown("---")

# ── churn section ─────────────────────────────────────────────
st.subheader("📉 MRR Movements")

churn_detail_query = f"""
    select movement_type,
           sum(customer_count) as customers,
           sum(abs_mrr_impact) as mrr_impact
    from raw_mart.mart_churn
    where batch_id = {selected_batch}
    {region_and_filter()}
    group by movement_type
    order by mrr_impact desc
"""
churn_detail_df = run_query(churn_detail_query)
if not churn_detail_df.empty:
    col_l, col_r = st.columns(2)
    with col_l:
        st.markdown("**Customer Movements**")
        st.bar_chart(churn_detail_df.set_index("movement_type")["customers"])
    with col_r:
        st.markdown("**MRR Impact ($)**")
        st.bar_chart(churn_detail_df.set_index("movement_type")["mrr_impact"])

st.markdown("---")

# ── usage section ─────────────────────────────────────────────
st.subheader("📈 Product Usage")

usage_query = f"""
    select metric_name,
           sum(total_quantity) as total_quantity,
           sum(active_customers) as active_customers
    from raw_mart.mart_usage
    {region_filter()}
    group by metric_name
    order by total_quantity desc
"""
usage_df = run_query(usage_query)
if not usage_df.empty:
    col_l, col_r = st.columns(2)
    with col_l:
        st.markdown("**Total Usage by Metric**")
        st.bar_chart(usage_df.set_index("metric_name")["total_quantity"])
    with col_r:
        st.markdown("**Active Customers by Metric**")
        st.bar_chart(usage_df.set_index("metric_name")["active_customers"])

st.markdown("---")

# ── support section ───────────────────────────────────────────
st.subheader("🎫 Support Health")

support_query = f"""
    select region,
           round(avg(avg_resolution_hours)::numeric, 1) as avg_resolution_hours,
           round(avg(avg_satisfaction_score)::numeric, 2) as avg_satisfaction,
           sum(total_tickets) as total_tickets
    from raw_mart.mart_support
    {region_filter()}
    group by region
    order by region
"""
support_df = run_query(support_query)
if not support_df.empty:
    st.dataframe(support_df, width='stretch')

st.markdown("---")
st.caption("NexusFlow Data Platform | Built with dbt + PostgreSQL + Streamlit")