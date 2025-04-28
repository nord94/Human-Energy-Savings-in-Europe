import os
import logging
import psycopg2
from datetime import datetime, timedelta
import subprocess
from pathlib import Path

from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator

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
    description='Transform data in the DWH using dbt',
    schedule_interval='@daily',
    start_date=datetime(2025, 4, 28),
    catchup=False,
    tags=['transform', 'dbt', 'dwh'],
) as dag:
    
    # Task to check database connection
    check_db_connection_task = PythonOperator(
        task_id='check_db_connection',
        python_callable=check_database_connection,
    )
    
    # Task to run dbt debug
    dbt_debug_task = BashOperator(
        task_id='dbt_debug',
        bash_command='cd /opt/airflow/dbt && bash run_dbt.sh debug',
        env={
            'DWH_CONN_URI': '{{ var.value.DWH_CONN_URI }}',
        },
    )
    
    # Task to run dbt models
    dbt_run_task = BashOperator(
        task_id='dbt_run',
        bash_command='cd /opt/airflow/dbt && bash run_dbt.sh run',
        env={
            'DWH_CONN_URI': '{{ var.value.DWH_CONN_URI }}',
        },
    )
    
    # Task to test dbt models
    dbt_test_task = BashOperator(
        task_id='dbt_test',
        bash_command='cd /opt/airflow/dbt && bash run_dbt.sh test',
        env={
            'DWH_CONN_URI': '{{ var.value.DWH_CONN_URI }}',
        },
    )
    
    # Set task dependencies
    check_db_connection_task >> dbt_debug_task >> dbt_run_task >> dbt_test_task 