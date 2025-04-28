FROM apache/airflow:2.8.1

USER root

# Install additional packages
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
        wget \
        vim \
    && apt-get autoremove -yqq --purge \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

USER airflow

# Initialize the database
RUN airflow db init

# Create default admin user
RUN airflow users create \
    --username admin \
    --password admin \
    --firstname Admin \
    --lastname User \
    --role Admin \
    --email admin@example.com

HEALTHCHECK CMD curl --fail http://localhost:8080/health || exit 1 