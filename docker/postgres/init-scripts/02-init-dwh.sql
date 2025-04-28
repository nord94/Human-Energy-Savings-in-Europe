-- Create schema for the energy data warehouse
CREATE SCHEMA IF NOT EXISTS energy_data;

-- Set default privileges
ALTER DEFAULT PRIVILEGES 
IN SCHEMA energy_data 
GRANT ALL ON TABLES TO dwh_user;

-- Create a test table for energy consumption data
CREATE TABLE IF NOT EXISTS energy_data.consumption (
    id SERIAL PRIMARY KEY,
    country VARCHAR(50) NOT NULL,
    date DATE NOT NULL,
    consumption_mwh DECIMAL(18,2) NOT NULL,
    population INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create an index on country and date
CREATE INDEX IF NOT EXISTS idx_consumption_country_date ON energy_data.consumption(country, date);

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA energy_data TO dwh_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA energy_data TO dwh_user; 