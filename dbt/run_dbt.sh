#!/bin/bash
set -e

# Set environment variables from Airflow connection if provided
if [ ! -z "$DWH_CONN_URI" ]; then
  # Parse connection URI
  # Format: postgresql+psycopg2://username:password@hostname:port/database
  conn_uri=${DWH_CONN_URI}
  
  # Extract username and password
  userpass=$(echo $conn_uri | sed -E 's/.*:\/\/(.*)@.*/\1/')
  username=$(echo $userpass | cut -d: -f1)
  password=$(echo $userpass | cut -d: -f2)
  
  # Extract host, port, and database
  hostdbname=$(echo $conn_uri | sed -E 's/.*@(.*)/\1/')
  hostport=$(echo $hostdbname | cut -d/ -f1)
  dbname=$(echo $hostdbname | cut -d/ -f2)
  
  host=$(echo $hostport | cut -d: -f1)
  port=$(echo $hostport | cut -d: -f2)
  
  # Set DBT environment variables
  export DBT_HOST=$host
  export DBT_PORT=$port
  export DBT_USER=$username
  export DBT_PASSWORD=$password
  export DBT_DATABASE=$dbname
fi

# Set the profiles directory
export DBT_PROFILES_DIR="$(dirname $0)"

# Run dbt with specified command or default to run
cd "$(dirname $0)/human_energy_project"
dbt "$@" || dbt run 