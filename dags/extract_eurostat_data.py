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

# URLs of the Eurostat CSV data
age_structure_url = "https://ec.europa.eu/eurostat/api/dissemination/sdmx/3.0/data/dataflow/ESTAT/tps00010/1.0?compress=false&format=csvdata&formatVersion=2.0&lang=en&labels=name"
total_population_url = "https://ec.europa.eu/eurostat/databrowser/view/tps00001/default/table?lang=en&category=t_demo.t_demo_pop"

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

# Table name for Eurostat data
TABLE_NAME = "eurostat_population_data"

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

def process_eurostat_age_data(**kwargs):
    """Download Eurostat age structure CSV data and use COPY for bulk insert"""
    logger = logging.getLogger(__name__)
    conn = None
    temp_file = None
    
    try:
        # Get database connection parameters
        conn_params = get_dwh_connection_params()
        
        # Download the CSV file
        logger.info("Downloading Eurostat age structure data...")
        response = requests.get(age_structure_url, stream=True)
        response.raise_for_status()
        
        # Read all content and decode
        content = response.content.decode('utf-8')
        
        # Verify we have content
        if not content or len(content) < 100:
            logger.error("Downloaded content appears to be empty or too small")
            logger.error(f"Content preview: {content[:100]}")
            raise ValueError("Invalid content downloaded")
            
        # Parse the CSV to get headers
        logger.info("Processing Eurostat age structure data...")
        csv_data = io.StringIO(content)
        reader = csv.reader(csv_data)
        
        # Get headers
        try:
            headers = next(reader)
            logger.info(f"Headers found: {len(headers)} columns")
            logger.info(f"First few headers: {headers[:5]}...")
        except StopIteration:
            logger.error("Could not read headers from CSV")
            raise ValueError("No headers found in CSV data")
        
        # Create a temporary file for the data
        temp_file = tempfile.NamedTemporaryFile(mode='w+', delete=False, suffix='.csv')
        writer = csv.writer(temp_file)
        writer.writerow(headers)  # Write headers
        
        # Copy all rows to the temporary file
        total_rows = 0
        for row in reader:
            if len(row) == len(headers):  # Ensure data integrity
                writer.writerow(row)
                total_rows += 1
                
        temp_file.close()
        
        if total_rows == 0:
            logger.warning("No data rows found in the CSV")
            raise ValueError("No data rows in CSV")
            
        logger.info(f"Processed {total_rows} data rows")
        
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
        logger.info(f"Successfully imported {count} rows into the database")
        
        if count == 0:
            logger.warning("No rows were inserted into the database")
        elif count != total_rows:
            logger.warning(f"Expected {total_rows} rows but inserted {count}")
            
        return count
        
    except Exception as e:
        logger.error(f"Error processing Eurostat age structure data: {e}")
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

def process_eurostat_total_population(**kwargs):
    """Download Eurostat total population data and append to the same table"""
    logger = logging.getLogger(__name__)
    conn = None
    temp_file = None
    
    try:
        # Get database connection parameters
        conn_params = get_dwh_connection_params()
        
        # Instead of trying to parse the HTML page, use the direct API endpoint
        # Similar to the age structure URL but with a different dataset code (tps00001)
        logger.info("Using direct Eurostat API for total population data...")
        direct_api_url = "https://ec.europa.eu/eurostat/api/dissemination/sdmx/3.0/data/dataflow/ESTAT/tps00001/1.0?compress=false&format=csvdata&formatVersion=2.0&lang=en&labels=name"
        
        # Download the CSV file
        logger.info(f"Downloading population data from Eurostat API...")
        response = requests.get(direct_api_url, stream=True)
        response.raise_for_status()
        
        # Read all content and decode
        content = response.content.decode('utf-8')
        
        # Verify we have content
        if not content or len(content) < 100:  # Basic sanity check
            logger.error("Downloaded content appears to be empty or too small")
            logger.error(f"Content preview: {content[:100]}")
            raise ValueError("Invalid content downloaded")
        
        # Parse the CSV to get headers
        logger.info("Processing Eurostat total population data...")
        csv_data = io.StringIO(content)
        reader = csv.reader(csv_data)
        
        # Get headers
        try:
            headers = next(reader)
            logger.info(f"Headers found: {len(headers)} columns")
            logger.info(f"First few headers: {headers[:5]}...")
        except StopIteration:
            logger.error("Could not read headers from CSV")
            raise ValueError("No headers found in CSV data")
        
        # Create a temporary file for the data
        temp_file = tempfile.NamedTemporaryFile(mode='w+', delete=False, suffix='.csv')
        writer = csv.writer(temp_file)
        writer.writerow(headers)  # Write headers
        
        # Copy all rows to the temporary file
        total_rows = 0
        for row in reader:
            if len(row) == len(headers):  # Ensure data integrity
                writer.writerow(row)
                total_rows += 1
                
        temp_file.close()
        
        if total_rows == 0:
            logger.warning("No data rows found in the CSV")
            raise ValueError("No data rows in CSV")
            
        logger.info(f"Processed {total_rows} data rows")
        
        # Connect to PostgreSQL
        conn = psycopg2.connect(**conn_params)
        cursor = conn.cursor()
        
        # Check if table exists
        cursor.execute(f"SELECT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = '{TABLE_NAME.lower()}');")
        table_exists = cursor.fetchone()[0]
        
        if not table_exists:
            # Create the table if it doesn't exist
            create_table(cursor, headers)
        else:
            logger.info(f"Table {TABLE_NAME} already exists, appending data...")
        
        # Use COPY command for bulk insert
        logger.info("Performing bulk insert of total population data with COPY...")
        with open(temp_file.name, 'r') as f:
            # Skip the header row
            next(f)
            cursor.copy_expert(
                f"COPY {TABLE_NAME} FROM STDIN WITH CSV",
                f
            )
        
        # Verify data was inserted
        cursor.execute(f"SELECT COUNT(*) FROM {TABLE_NAME}")
        total_count = cursor.fetchone()[0]
        
        conn.commit()
        logger.info(f"Successfully imported total population data. Table now has {total_count} rows.")
        
        return total_count
        
    except Exception as e:
        logger.error(f"Error processing Eurostat total population data: {e}")
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
    'extract_eurostat_data',
    default_args=default_args,
    description='Extract population data from Eurostat',
    schedule_interval='@daily',
    start_date=datetime(2025, 4, 28),
    catchup=False,
    tags=['eurostat', 'population', 'extract'],
) as dag:
    
    # Task to check database connection
    check_db_connection_task = PythonOperator(
        task_id='check_db_connection',
        python_callable=check_database_connection,
    )
    
    # Task to process Eurostat age structure data
    process_age_data_task = PythonOperator(
        task_id='process_age_data',
        python_callable=process_eurostat_age_data,
    )
    
    # Task to process Eurostat total population data
    process_total_population_task = PythonOperator(
        task_id='process_total_population',
        python_callable=process_eurostat_total_population,
    )
    
    # Set the task dependencies
    check_db_connection_task >> process_age_data_task >> process_total_population_task