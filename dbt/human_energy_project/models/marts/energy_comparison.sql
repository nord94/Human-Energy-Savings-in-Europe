with population_processed as (
    select
        ap.*,
        aag.total_population_by_age_group/100 as target_population_percentage
    from {{ ref('stg_eurostat_population') }} ap
    join {{ ref('stg_eurostat_age_groups') }} aag 
        on ap.geo = aag.geo and ap.time_period = aag.time_period
)

-- Power plant energy output in MWattHrs per week
select
    country_long as country,
    primary_fuel as fuel,
    (total_power_out_mw*7*24*60*60)::bigint as mwatthrs_per_week
from {{ ref('stg_european_power_plants') }}

union all

-- Human power contribution
select
    country,
    'Human power' as fuel,
    round(CAST(400 * total_population / 1000000 AS numeric), 2) as mwatthrs_per_week
from population_processed
where time_period = '2024' 