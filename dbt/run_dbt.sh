#!/bin/bash
set -e

echo "Starting dbt script..."

# Set environment variables from Airflow connection if provided
if [ ! -z "$DWH_CONN_URI" ]; then
  echo "Found DWH_CONN_URI, parsing it for dbt..."
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
  
  echo "DBT environment variables set from DWH_CONN_URI"
fi

# Find dbt executable
DBT_COMMAND=""
for path in /home/airflow/.local/bin/dbt /usr/local/bin/dbt /usr/bin/dbt $(which dbt 2>/dev/null)
do
  if [ -x "$path" ]; then
    DBT_COMMAND="$path"
    echo "Found dbt executable at: $DBT_COMMAND"
    break
  fi
done

if [ -z "$DBT_COMMAND" ]; then
  echo "dbt executable not found in common locations, trying python module"
  DBT_COMMAND="python -m dbt"
fi

# Set the profiles directory
export DBT_PROFILES_DIR="$(dirname $0)"
echo "Using profiles directory: $DBT_PROFILES_DIR"

# Run dbt with specified command or default to run
cd "$(dirname $0)/human_energy_project"
echo "Working directory: $(pwd)"
echo "Running dbt command: $DBT_COMMAND $@"
$DBT_COMMAND "$@" || $DBT_COMMAND run 