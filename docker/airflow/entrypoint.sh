#!/bin/bash
set -e

# Wait for PostgreSQL to become available
function wait_for_postgres() {
  echo "Waiting for PostgreSQL to become available..."
  local retry_count=0
  local max_retries=30
  local retry_interval=5

  # Extract PostgreSQL hostname from connection string
  if [[ $AIRFLOW__CORE__SQL_ALCHEMY_CONN =~ .*@([^:]+):.* ]]; then
    local pg_host="${BASH_REMATCH[1]}"
    echo "PostgreSQL host: $pg_host"
    
    until pg_isready -h "$pg_host" -U airflow || [ $retry_count -eq $max_retries ]; do
      echo "PostgreSQL is unavailable - sleeping for ${retry_interval}s"
      sleep $retry_interval
      retry_count=$((retry_count+1))
    done
  else
    echo "Could not extract PostgreSQL host from connection string"
    return 1
  fi

  if [ $retry_count -eq $max_retries ]; then
    echo "Could not connect to PostgreSQL after $max_retries attempts - giving up"
    return 1
  fi

  echo "PostgreSQL is up and running!"
  return 0
}

# Initialize the database if needed
if wait_for_postgres; then
  echo "Initializing Airflow database..."
  airflow db init

  # Check if admin user exists, create if it doesn't
  if ! airflow users list | grep -q "admin"; then
    echo "Creating admin user..."
    airflow users create \
      --username admin \
      --password admin \
      --firstname Admin \
      --lastname User \
      --role Admin \
      --email admin@example.com
  fi
fi

# Execute the provided command
exec airflow "$@" 