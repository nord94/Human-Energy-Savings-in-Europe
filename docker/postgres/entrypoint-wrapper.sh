#!/bin/bash
set -e

# Create init directory if it doesn't exist
mkdir -p /docker-entrypoint-initdb.d/

# Copy appropriate init scripts based on database name
if [ "$POSTGRES_DB" = "airflow" ]; then
  echo "Setting up Airflow database initialization scripts"
  cp /tmp/init-scripts/01-init.sql /docker-entrypoint-initdb.d/
elif [ "$POSTGRES_DB" = "energy_dwh" ]; then
  echo "Setting up Energy DWH database initialization scripts"
  cp /tmp/init-scripts/02-init-dwh.sql /docker-entrypoint-initdb.d/
else
  echo "Unknown database name: $POSTGRES_DB, no specific initialization"
fi

# Run the original entrypoint script
exec docker-entrypoint.sh "$@" 