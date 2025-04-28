-- Create schema for Airflow if it doesn't exist
CREATE SCHEMA IF NOT EXISTS airflow;

-- Set default privileges
ALTER DEFAULT PRIVILEGES 
IN SCHEMA airflow 
GRANT ALL ON TABLES TO airflow;

-- Add any additional database configurations needed
SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on; 