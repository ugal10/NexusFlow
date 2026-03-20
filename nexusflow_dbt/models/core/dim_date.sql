-- dim_date: date spine covering all data range
-- generates one row per date from 2024-01-01 to 2024-12-31
with date_spine as (
    select generate_series(
        '2024-01-01'::date,
        '2024-12-31'::date,
        '1 day'::interval
    )::date as date_day
)

select
    date_day,
    extract(year from date_day)::int        as year,
    extract(month from date_day)::int       as month,
    extract(quarter from date_day)::int     as quarter,
    extract(dow from date_day)::int         as day_of_week,
    extract(day from date_day)::int         as day_of_month,
    to_char(date_day, 'Month')              as month_name,
    to_char(date_day, 'YYYY-MM')            as year_month,
    case when extract(dow from date_day) in (0,6) 
        then true else false end            as is_weekend
from date_spine