-- ============================================================
-- nexusflow access control
-- roles: admin, analyst, viewer, regional_manager
-- rls enforced at data layer for regional managers
-- ============================================================

-- create roles
create role nexusflow_admin;
create role nexusflow_analyst;
create role nexusflow_viewer;
create role nexusflow_regional_manager;

-- create example users
create user admin_user with password 'admin123' in role nexusflow_admin;
create user analyst_user with password 'analyst123' in role nexusflow_analyst;
create user viewer_user with password 'viewer123' in role nexusflow_viewer;

-- regional manager users (one per region)
create user manager_na with password 'manager123' in role nexusflow_regional_manager;
create user manager_emea with password 'manager123' in role nexusflow_regional_manager;
create user manager_apac with password 'manager123' in role nexusflow_regional_manager;

-- store region mapping for rls
create table if not exists public.user_region_map (
    username text primary key,
    region   text not null
);

insert into public.user_region_map values
    ('manager_na',   'NA'),
    ('manager_emea', 'EMEA'),
    ('manager_apac', 'APAC');

-- ============================================================
-- schema permissions
-- ============================================================

-- admin: full access to everything
grant all privileges on schema raw_stage, raw_core, raw_mart, raw to nexusflow_admin;
grant all privileges on all tables in schema raw_stage, raw_core, raw_mart, raw to nexusflow_admin;

-- analyst: read access to stage, core, mart (not raw)
grant usage on schema raw_stage, raw_core, raw_mart to nexusflow_analyst;
grant select on all tables in schema raw_stage, raw_core, raw_mart to nexusflow_analyst;

-- viewer: read access to mart only
grant usage on schema raw_mart to nexusflow_viewer;
grant select on all tables in schema raw_mart to nexusflow_viewer;

-- regional manager: read access to mart only (rls filters by region)
grant usage on schema raw_mart to nexusflow_regional_manager;
grant select on all tables in schema raw_mart to nexusflow_regional_manager;

-- ============================================================
-- row level security for regional managers
-- ============================================================

-- enable rls on mart tables that have region column
alter table raw_mart.mart_mrr enable row level security;
alter table raw_mart.mart_churn enable row level security;
alter table raw_mart.mart_nrr enable row level security;
alter table raw_mart.mart_support enable row level security;
alter table raw_mart.mart_usage enable row level security;

-- policy: regional managers see only their region
-- admins and analysts bypass rls
create policy region_isolation on raw_mart.mart_mrr
    for select
    using (
        current_user not in (select username from public.user_region_map)
        or region = (
            select region from public.user_region_map
            where username = current_user
        )
    );

create policy region_isolation on raw_mart.mart_churn
    for select
    using (
        current_user not in (select username from public.user_region_map)
        or region = (
            select region from public.user_region_map
            where username = current_user
        )
    );

create policy region_isolation on raw_mart.mart_nrr
    for select
    using (
        current_user not in (select username from public.user_region_map)
        or region = (
            select region from public.user_region_map
            where username = current_user
        )
    );

create policy region_isolation on raw_mart.mart_support
    for select
    using (
        current_user not in (select username from public.user_region_map)
        or region = (
            select region from public.user_region_map
            where username = current_user
        )
    );

create policy region_isolation on raw_mart.mart_usage
    for select
    using (
        current_user not in (select username from public.user_region_map)
        or region = (
            select region from public.user_region_map
            where username = current_user
        )
    );

-- admins bypass rls entirely
alter table raw_mart.mart_mrr force row level security;
alter table raw_mart.mart_churn force row level security;
alter table raw_mart.mart_nrr force row level security;
alter table raw_mart.mart_support force row level security;
alter table raw_mart.mart_usage force row level security;