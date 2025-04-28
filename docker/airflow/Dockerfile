FROM apache/airflow:2.8.1

USER root

# Install additional packages
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
        wget \
        vim \
        postgresql-client \
    && apt-get autoremove -yqq --purge \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER airflow

# Install additional Python packages
RUN pip install --no-cache-dir \
    sqlalchemy \
    psycopg2-binary

HEALTHCHECK CMD curl --fail http://localhost:8080/health || exit 1

ENTRYPOINT ["/entrypoint.sh"] 