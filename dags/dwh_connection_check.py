import os
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
import sqlalchemy
import logging

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 3,
    'retry_delay': timedelta(minutes=5),
}

def check_dwh_connection():
    """
    Check connection to the DWH database.
    """
    logger = logging.getLogger(__name__)
    dwh_uri = os.environ.get('DWH_CONN_URI')
    
    if not dwh_uri:
        raise ValueError("DWH_CONN_URI environment variable not set")
    
    logger.info(f"Attempting to connect to DWH using connection URI: {dwh_uri}")
    
    try:
        engine = sqlalchemy.create_engine(dwh_uri)
        connection = engine.connect()
        logger.info("Successfully connected to the DWH database")
        
        # Execute a simple query to make sure everything is working
        result = connection.execute(sqlalchemy.text("SELECT 1 as test")).fetchone()
        logger.info(f"Test query result: {result}")
        
        connection.close()
        return "Connection successful: " + str(datetime.now())
    except Exception as e:
        logger.error(f"Failed to connect to the DWH database: {str(e)}")
        raise e

with DAG(
    'dwh_connection_check',
    default_args=default_args,
    description='Checks connection to the DWH database once a day',
    schedule_interval='@daily',
    start_date=datetime(2025, 4, 28),
    catchup=False,
    tags=['dwh', 'connection', 'check'],
) as dag:
    
    check_connection_task = PythonOperator(
        task_id='check_dwh_connection',
        python_callable=check_dwh_connection,
    ) 