with source as (
    select 
        *
    from eurostat_population_data
    where "STRUCTURE_NAME" = 'Population on 1 January'
)

select distinct 
    geo,
    "TIME_PERIOD" as time_period,
    "Geopolitical entity (reporting)" as country,
    sum(CAST(coalesce("OBS_VALUE", '0') AS float)) as total_population
from source
group by geo, "TIME_PERIOD", country 