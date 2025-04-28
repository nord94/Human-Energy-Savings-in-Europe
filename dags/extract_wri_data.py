import os
import requests
import psycopg2
import csv
import io
import tempfile
from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.python import PythonOperator
import logging

# URL of the Global Power Plant Database CSV file
data_url = "https://github.com/wri/global-power-plant-database/raw/master/output_database/global_power_plant_database.csv"

# List of European countries
EUROPEAN_COUNTRIES = {
    "Albania", "Andorra", "Austria", "Belarus", "Belgium", "Bosnia and Herzegovina", "Bulgaria",
    "Croatia", "Cyprus", "Czech Republic", "Denmark", "Estonia", "Finland", "France", "Germany",
    "Greece", "Hungary", "Iceland", "Ireland", "Italy", "Latvia", "Liechtenstein", "Lithuania",
    "Luxembourg", "Malta", "Moldova", "Monaco", "Montenegro", "Netherlands", "North Macedonia",
    "Norway", "Poland", "Portugal", "Romania", "San Marino", "Serbia", "Slovakia", "Slovenia",
    "Spain", "Sweden", "Switzerland", "Ukraine", "United Kingdom", "Vatican City"
}

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
    }

# Table name for power plant data
TABLE_NAME = "european_power_plants"

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

def create_table(cursor, headers):
    """Create the database table based on CSV headers"""
    cursor.execute(f"DROP TABLE IF EXISTS {TABLE_NAME};")
    columns_with_types = ", ".join([f'"{header}" TEXT' for header in headers])
    cursor.execute(f"CREATE TABLE {TABLE_NAME} ({columns_with_types});")
    logging.info(f"Table {TABLE_NAME} created successfully")

def process_wri_data(**kwargs):
    """Download CSV, filter European data, and use COPY for bulk insert"""
    logger = logging.getLogger(__name__)
    conn = None
    temp_file = None
    
    try:
        # Get database connection parameters
        conn_params = get_dwh_connection_params()
        
        # Download the CSV file with explicit streaming
        logger.info("Downloading WRI power plant data...")
        response = requests.get(data_url, stream=True)
        response.raise_for_status()
        
        # Read all content and decode
        content = response.content.decode('utf-8')
        
        # Verify we have content
        if not content or len(content) < 100:  # Basic sanity check
            logger.error("Downloaded content appears to be empty or too small")
            logger.error(f"Content preview: {content[:100]}")
            raise ValueError("Invalid content downloaded")
            
        # Parse the CSV to get headers and filter European countries
        logger.info("Filtering data for European countries...")
        csv_data = io.StringIO(content)
        reader = csv.reader(csv_data)
        
        # Get headers
        try:
            headers = next(reader)
            logger.info(f"Headers found: {headers}")
        except StopIteration:
            logger.error("Could not read headers from CSV")
            raise ValueError("No headers found in CSV data")
        
        # Find the country column index
        if "country" not in headers and "country_long" not in headers:
            logger.error("No country column found in headers")
            raise ValueError("Missing country column in CSV data")
            
        country_index = headers.index("country_long") if "country_long" in headers else headers.index("country")
        
        # Create a temporary file for the filtered European data
        temp_file = tempfile.NamedTemporaryFile(mode='w+', delete=False, suffix='.csv')
        writer = csv.writer(temp_file)
        writer.writerow(headers)  # Write headers
        
        # Filter rows for European countries only
        european_rows = 0
        total_rows = 0
        
        for row in reader:
            total_rows += 1
            if len(row) == len(headers) and row[country_index].strip() in EUROPEAN_COUNTRIES:
                writer.writerow(row)
                european_rows += 1
                
        temp_file.close()
        
        if european_rows == 0:
            logger.warning(f"No European power plants found among {total_rows} total rows")
            raise ValueError("No European power plants found in data")
            
        logger.info(f"Filtered {european_rows} European power plant entries from {total_rows} total")
        
        # Connect to PostgreSQL
        conn = psycopg2.connect(**conn_params)
        cursor = conn.cursor()
        
        # Create the table
        create_table(cursor, headers)
        
        # Use COPY command for bulk insert
        logger.info("Performing bulk insert with COPY...")
        with open(temp_file.name, 'r') as f:
            # Skip the header row as we already created the table
            next(f)
            cursor.copy_expert(
                f"COPY {TABLE_NAME} FROM STDIN WITH CSV",
                f
            )
        
        # Verify data was inserted
        cursor.execute(f"SELECT COUNT(*) FROM {TABLE_NAME}")
        count = cursor.fetchone()[0]
        
        conn.commit()
        logger.info(f"Successfully imported {count} European power plant rows")
        
        if count == 0:
            logger.warning("No rows were inserted into the database")
        elif count != european_rows - 1:  # -1 because we skip the header in COPY
            logger.warning(f"Expected {european_rows-1} rows but inserted {count}")
            
        return count
        
    except Exception as e:
        logger.error(f"Error processing WRI data: {e}")
        if conn:
            conn.rollback()
        raise
    finally:
        if conn:
            cursor.close()
            conn.close()
            logger.info("Database connection closed")
        
        # Clean up the temporary file
        if temp_file and os.path.exists(temp_file.name):
            os.unlink(temp_file.name)
            logger.info("Temporary file deleted")

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
    'extract_wri_power_plants',
    default_args=default_args,
    description='Extract European power plant data from WRI database',
    schedule_interval='@weekly',  # Less frequent than population data
    start_date=datetime(2025, 4, 28),
    catchup=False,
    tags=['wri', 'power_plants', 'extract', 'europe'],
) as dag:
    
    # Task to check database connection
    check_db_connection_task = PythonOperator(
        task_id='check_db_connection',
        python_callable=check_database_connection,
    )
    
    # Task to process WRI data
    process_wri_data_task = PythonOperator(
        task_id='process_wri_data',
        python_callable=process_wri_data,
    )
    
    # Set the task dependencies
    check_db_connection_task >> process_wri_data_task