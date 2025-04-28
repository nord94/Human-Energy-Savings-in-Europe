import os
import logging
import psycopg2
from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.postgres.operators.postgres import PostgresOperator

# DWH connection parameters (from environment variables)
def get_dwh_connection_params():
    conn_uri = os.environ.get('DWH_CONN_URI')
    if not conn_uri:
        raise ValueError("DWH_CONN_URI environment variable not set")
    
    # Parse PostgreSQL connection URI
    # Format: postgresql+psycopg2://username:password@hostname:port/database
    conn_parts = conn_uri.replace("postgresql+psycopg2://", "").split("@")
    user_pass = conn_parts[0].split(":")
    host_db = conn_parts[1].split("/")
    
    return {
        "dbname": host_db[1],
        "user": user_pass[0],
        "password": user_pass[1],
        "host": host_db[0].split(":")[0],
        "port": host_db[0].split(":")[1] if ":" in host_db[0] else "5432",
    }

# Function to check database connection
def check_database_connection(**kwargs):
    """Check if we can connect to the database"""
    logger = logging.getLogger(__name__)
    conn_params = get_dwh_connection_params()
    
    try:
        logger.info(f"Connecting to database {conn_params['dbname']} on {conn_params['host']}...")
        conn = psycopg2.connect(**conn_params)
        conn.close()
        logger.info("Database connection successful")
        return True
    except Exception as e:
        logger.error(f"Database connection error: {e}")
        raise

# Function to execute SQL transformation
def execute_transformation(**kwargs):
    """Execute SQL transformation directly using psycopg2"""
    logger = logging.getLogger(__name__)
    conn_params = get_dwh_connection_params()
    
    try:
        # Connect to the database
        logger.info(f"Connecting to database to run transformations...")
        conn = psycopg2.connect(**conn_params)
        cursor = conn.cursor()
        
        # Create the table
        logger.info("Creating energy_comparison table...")
        cursor.execute("""
        DROP TABLE IF EXISTS energy_comparison;
        CREATE TABLE energy_comparison (
            country VARCHAR(255),
            fuel VARCHAR(255),
            mwatthrs_per_week BIGINT
        );
        """)
        
        # Run the transformation query
        logger.info("Executing transformation query...")
        cursor.execute("""
        INSERT INTO energy_comparison (country, fuel, mwatthrs_per_week)
        with agg_age_groups as (
            select 
                geo
                , "Geopolitical entity (reporting)" as country
                , "TIME_PERIOD" as time_period
                , sum(CAST(coalesce("OBS_VALUE", '0') AS float)) as total_population_by_age_group
            from eurostat_population_data
                where "STRUCTURE_NAME" = 'Population by age group'
                    and indic_de = ANY ('{PC_Y15_24,PC_Y25_49,PC_Y50_64}')
                group by geo, "TIME_PERIOD", country
        ), agg_population as (
            select distinct 
                geo
                , "TIME_PERIOD" as time_period
                , "Geopolitical entity (reporting)" as country
                , sum(CAST(coalesce("OBS_VALUE", '0') AS float)) as total_population
            from eurostat_population_data
                where "STRUCTURE_NAME" = 'Population on 1 January'
                group by geo, "TIME_PERIOD", country
        ), population_processed as (
            select
                ap.*
                , aag.total_population_by_age_group/100 target_population_percentage
            from agg_population ap
                join agg_age_groups aag on ap.geo = aag.geo and ap.time_period = aag.time_period
                order by country, time_period asc
        ), tmp as (
            select 
                *
                , CAST(coalesce(capacity_mw, '0') AS float) capacity_mw_int
            from european_power_plants epp2 
        ), pre_agg as (
            select 
                country_long
                , epp.primary_fuel
                , sum(capacity_mw_int) as total_power_out_mw
            from tmp epp
                    group by epp.country_long, epp.primary_fuel
                    order by primary_fuel 
        )
        select
            country_long country
            , primary_fuel as fuel
            , (total_power_out_mw*7*24*60*60)::bigint MWattHrs_per_week
        from pre_agg
         union all
        select
            country
            , 'Human power'
            , round(CAST(400 * total_population / 1000000 AS numeric), 2)
        from population_processed
            where 1=1
                and time_period = '2024'
            order by country, fuel
        """)
        
        # Commit the transaction
        conn.commit()
        
        # Verify data was inserted
        cursor.execute("SELECT COUNT(*) FROM energy_comparison")
        count = cursor.fetchone()[0]
        logger.info(f"Successfully transformed data. energy_comparison table has {count} rows.")
        
        # Close cursor and connection
        cursor.close()
        conn.close()
        
        return count
    except Exception as e:
        logger.error(f"Error executing transformation: {e}")
        if conn:
            conn.rollback()
        raise

# Define default DAG arguments
default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 3,
    'retry_delay': timedelta(minutes=5),
}

# Define the DAG
with DAG(
    'transform_data',
    default_args=default_args,
    description='Transform data in the DWH using SQL',
    schedule_interval='@daily',
    start_date=datetime(2025, 4, 28),
    catchup=False,
    tags=['transform', 'sql', 'dwh'],
) as dag:
    
    # Task to check database connection
    check_db_connection_task = PythonOperator(
        task_id='check_db_connection',
        python_callable=check_database_connection,
    )
    
    # Task to run SQL transformations
    execute_transform_task = PythonOperator(
        task_id='execute_transformation',
        python_callable=execute_transformation,
    )
    
    # Set task dependencies
    check_db_connection_task >> execute_transform_task 