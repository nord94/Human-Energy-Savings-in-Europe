# Clean up any previous containers
docker-compose down

# Remove the old volumes (optional, uncomment if you want to start fresh)
# docker volume rm human-energy-savings-in-europe_postgres-data

# Build and start the containers with no cache for Airflow
docker-compose -f docker-compose-build.yml build --no-cache airflow-webserver
docker-compose up -d

# Follow the logs to see what's happening
docker-compose logs -f airflow-webserver 