with source as (
    select 
        *,
        CAST(coalesce(capacity_mw, '0') AS float) as capacity_mw_int
    from european_power_plants
)

select 
    country_long,
    primary_fuel,
    sum(capacity_mw_int) as total_power_out_mw
from source
group by country_long, primary_fuel 