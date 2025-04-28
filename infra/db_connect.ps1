# PowerShell script to connect to and diagnose the Airflow PostgreSQL database

# Load database connection details from Terraform output
$DB_ENDPOINT = terraform output -raw airflow_db_endpoint
$DB_PASSWORD = terraform output -raw db_password 2>$null

if (-not $DB_PASSWORD) {
    $DB_PASSWORD = Read-Host "Enter the database password" -AsSecureString
    $DB_PASSWORD = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($DB_PASSWORD))
}

Write-Host "Attempting to connect to database at $DB_ENDPOINT..." -ForegroundColor Cyan

# Check if psql is installed
$psqlCheck = Get-Command psql -ErrorAction SilentlyContinue
if (-not $psqlCheck) {
    Write-Host "⚠️ PostgreSQL client (psql) not found! You may need to install PostgreSQL client tools." -ForegroundColor Yellow
    Write-Host "Download from: https://www.postgresql.org/download/windows/" -ForegroundColor Yellow
    exit 1
}

# Define diagnostic queries
$queries = @(
    "SELECT current_timestamp AS current_time;" # Check connectivity
    "SELECT count(*) FROM pg_database WHERE datname='airflow';" # Check if airflow DB exists
    "SELECT pg_database_size('airflow') / (1024*1024) AS airflow_size_mb;" # Check DB size
    "SELECT pg_total_relation_size('information_schema.tables') / (1024*1024) AS schema_size_mb;" # Check schema size
    "SELECT * FROM pg_stat_activity WHERE datname='airflow';" # Check active connections
    "SELECT setting FROM pg_settings WHERE name='max_connections';" # Check max connections
    "SELECT setting FROM pg_settings WHERE name='shared_buffers';" # Check shared buffers
)

# Run diagnostic queries
Write-Host "Running database diagnostics..." -ForegroundColor Cyan
foreach ($query in $queries) {
    Write-Host "`n> $query" -ForegroundColor Magenta
    
    $env:PGPASSWORD = $DB_PASSWORD
    psql -h $DB_ENDPOINT -U airflow -d postgres -c $query
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Command failed with exit code $LASTEXITCODE" -ForegroundColor Red
    }
}

# Try connecting to the airflow database specifically
Write-Host "`nAttempting to connect to the Airflow database..." -ForegroundColor Cyan
$env:PGPASSWORD = $DB_PASSWORD
psql -h $DB_ENDPOINT -U airflow -d airflow -c "SELECT 1 AS connection_test;"

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ Successfully connected to the Airflow database!" -ForegroundColor Green
    
    # Check for Airflow tables
    Write-Host "Checking for Airflow tables..." -ForegroundColor Cyan
    psql -h $DB_ENDPOINT -U airflow -d airflow -c "\dt"
} else {
    Write-Host "`n❌ Failed to connect to the Airflow database. It may not exist yet." -ForegroundColor Red
} 