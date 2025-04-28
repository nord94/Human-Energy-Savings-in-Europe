FROM postgres:14

# Set environment variables with defaults
ENV POSTGRES_USER=airflow
ENV POSTGRES_PASSWORD=airflow
ENV POSTGRES_DB=airflow

# Copy init scripts but don't run them yet
COPY ./init-scripts/ /tmp/init-scripts/

# Create a custom entrypoint script to select appropriate scripts
COPY ./entrypoint-wrapper.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint-wrapper.sh

# Health check
HEALTHCHECK --interval=5s --timeout=5s --retries=5 \
  CMD pg_isready -U ${POSTGRES_USER} || exit 1

ENTRYPOINT ["entrypoint-wrapper.sh"]
CMD ["postgres"] 