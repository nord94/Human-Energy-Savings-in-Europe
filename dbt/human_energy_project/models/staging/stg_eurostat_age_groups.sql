with source as (
    select 
        *
    from eurostat_population_data
    where "STRUCTURE_NAME" = 'Population by age group'
        and indic_de = ANY ('{PC_Y15_24,PC_Y25_49,PC_Y50_64}')
)

select 
    geo,
    "Geopolitical entity (reporting)" as country,
    "TIME_PERIOD" as time_period,
    sum(CAST(coalesce("OBS_VALUE", '0') AS float)) as total_population_by_age_group
from source
group by geo, "TIME_PERIOD", country 