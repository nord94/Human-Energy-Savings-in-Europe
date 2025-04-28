FROM postgres:14

# Set environment variables
ENV POSTGRES_USER airflow
ENV POSTGRES_PASSWORD airflow
ENV POSTGRES_DB airflow

# Add custom init scripts if needed
COPY ./init-scripts/ /docker-entrypoint-initdb.d/

# Health check
HEALTHCHECK --interval=5s --timeout=5s --retries=5 \
  CMD pg_isready -U airflow || exit 1 