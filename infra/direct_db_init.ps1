# Direct PostgreSQL Database Initialization Script for Airflow
# This script completely bypasses the Airflow DB initialization and manually creates the database tables

# Check if AWS CLI is installed
try {
    $awsVersion = aws --version
    Write-Host "* AWS CLI is available: $awsVersion" -ForegroundColor Green
} catch {
    Write-Host "X ERROR: AWS CLI is not installed or not in your PATH!" -ForegroundColor Red
    Write-Host "  Please install AWS CLI from: https://aws.amazon.com/cli/" -ForegroundColor Red
    exit 1
}

# Check if PostgreSQL client is installed
try {
    $psqlVersion = psql --version
    Write-Host "* PostgreSQL client is available: $psqlVersion" -ForegroundColor Green
} catch {
    Write-Host "X ERROR: PostgreSQL client (psql) is not installed or not in your PATH!" -ForegroundColor Red
    Write-Host "  Please install PostgreSQL client from: https://www.postgresql.org/download/windows/" -ForegroundColor Red
    exit 1
}

# Load configuration from Terraform output
$DB_ENDPOINT = terraform output -raw airflow_db_endpoint
$DB_PASSWORD = terraform output -raw db_password 2>$null

if (-not $DB_PASSWORD) {
    $DB_PASSWORD = Read-Host "Enter your database password"
}

Write-Host "Starting direct database initialization..." -ForegroundColor Cyan
$env:PGPASSWORD = $DB_PASSWORD

# Step 1: Verify we can connect to the PostgreSQL server
Write-Host "`nVerifying PostgreSQL connection..." -ForegroundColor Yellow
$pgConnTest = psql -h $DB_ENDPOINT -U airflow -d postgres -c "SELECT 1 AS connection_test;" -t
if ($LASTEXITCODE -ne 0) {
    Write-Host "X Connection to PostgreSQL server failed!" -ForegroundColor Red
    exit 1
}
Write-Host "* Successfully connected to PostgreSQL server" -ForegroundColor Green

# Step 2: Check if airflow database exists, create if it doesn't
Write-Host "`nChecking for Airflow database..." -ForegroundColor Yellow
$dbExists = psql -h $DB_ENDPOINT -U airflow -d postgres -c "SELECT count(*) FROM pg_database WHERE datname='airflow';" -t
$dbExists = $dbExists.Trim()

if ($dbExists -eq "0") {
    Write-Host "Creating airflow database..." -ForegroundColor Yellow
    psql -h $DB_ENDPOINT -U airflow -d postgres -c "CREATE DATABASE airflow;"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "X Failed to create airflow database!" -ForegroundColor Red
        exit 1
    }
    Write-Host "* Airflow database created successfully" -ForegroundColor Green
} else {
    Write-Host "* Airflow database already exists" -ForegroundColor Green
}

# Step 3: Check if we can connect to the airflow database
Write-Host "`nConnecting to Airflow database..." -ForegroundColor Yellow
$airflowConnTest = psql -h $DB_ENDPOINT -U airflow -d airflow -c "SELECT 1 AS connection_test;" -t
if ($LASTEXITCODE -ne 0) {
    Write-Host "X Connection to Airflow database failed!" -ForegroundColor Red
    exit 1
}
Write-Host "* Successfully connected to Airflow database" -ForegroundColor Green

# Step 4: Run minimal ECS task for database initialization with minimal environment
Write-Host "`nRunning minimal Airflow DB init task..." -ForegroundColor Yellow

# Load AWS configuration
$AWS_REGION = terraform output -raw aws_region
$CLUSTER_NAME = terraform output -raw airflow_cluster_name
$TASK_DEF_ARN = terraform output -raw airflow_db_upgrade_task_arn
$SUBNET_A = terraform output -raw public_subnet_a_id
$SUBNET_B = terraform output -raw public_subnet_b_id
$SG_ID = terraform output -raw ecs_security_group_id

# Define a completely minimal environment with absolute minimum configuration
$minimalEnv = @(
    "{""name"":""AIRFLOW__CORE__SQL_ALCHEMY_CONN"",""value"":""postgresql+psycopg2://airflow:$DB_PASSWORD@$DB_ENDPOINT/airflow""}",
    "{""name"":""AIRFLOW__DATABASE__LOAD_DEFAULT_CONNECTIONS"",""value"":""False""}",
    "{""name"":""AIRFLOW__LOGGING__LOGGING_LEVEL"",""value"":""DEBUG""}",
    "{""name"":""AIRFLOW__DATABASE__ENGINE_HEALTH_CHECK_TIMEOUT"",""value"":""30""}",
    "{""name"":""AIRFLOW__CORE__LOAD_EXAMPLES"",""value"":""False""}",
    "{""name"":""AIRFLOW__CORE__DAGS_FOLDER"",""value"":""/opt/airflow/dags""}"
)
$envJson = "[" + ($minimalEnv -join ",") + "]"

# Create a custom airflow.cfg to avoid any SQLAlchemy engine args issues
$customCmd = @'
set -ex
mkdir -p /tmp/airflow
cat > /tmp/airflow/airflow.cfg << 'EOL'
[database]
sql_alchemy_conn = postgresql+psycopg2://airflow:PASSWORD@HOST/airflow
load_default_connections = False

[logging]
logging_level = DEBUG

[core]
load_examples = False
dags_folder = /opt/airflow/dags
EOL

sed -i "s/PASSWORD/$DB_PASSWORD/g" /tmp/airflow/airflow.cfg
sed -i "s/HOST/$DB_ENDPOINT/g" /tmp/airflow/airflow.cfg

export AIRFLOW_HOME=/tmp/airflow
timeout 90 airflow db init
'@

# Remove newlines and escape quotes for JSON
$customCmd = $customCmd.Replace("`r`n", " ").Replace("`n", " ")
$customCmd = $customCmd.Replace('"', '\"')

# Run the ECS task with custom command and minimal environment
$runTaskCmd = "aws ecs run-task " + `
    "--cluster $CLUSTER_NAME " + `
    "--task-definition $TASK_DEF_ARN " + `
    "--launch-type FARGATE " + `
    "--network-configuration ""awsvpcConfiguration={subnets=[$SUBNET_A,$SUBNET_B],securityGroups=[$SG_ID],assignPublicIp=ENABLED}"" " + `
    "--overrides ""{""""containerOverrides"""":[{""""name"""":""""airflow-db-upgrade"""",""""command"""":[""""bash"""",""""""-c"""""""",""""$customCmd""""],""""environment"""":$envJson}]}"" " + `
    "--region $AWS_REGION"

Write-Host "Running task with custom command to avoid connect_args conflict..." -ForegroundColor Yellow
$taskOutput = Invoke-Expression $runTaskCmd | ConvertFrom-Json

if (-not $taskOutput.tasks) {
    Write-Host "X Failed to start ECS task!" -ForegroundColor Red
    Write-Host $taskOutput -ForegroundColor Red
    exit 1
}

$TASK_ARN = $taskOutput.tasks[0].taskArn
$TASK_ID = $TASK_ARN.Split('/')[-1]

Write-Host "Task started with ARN: $TASK_ARN" -ForegroundColor Green

# Monitor task status
Write-Host "`nMonitoring task status..." -ForegroundColor Yellow
$status = "PENDING"
do {
    Start-Sleep -Seconds 5
    $status = aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $TASK_ARN --region $AWS_REGION --query 'tasks[0].lastStatus' --output text
    Write-Host "Current status: $status" -ForegroundColor Yellow
    
    # Try to get available logs
    try {
        aws logs get-log-events --log-group-name "/ecs/airflow" --log-stream-name "ecs-db-upgrade/airflow-db-upgrade/$TASK_ID" --region $AWS_REGION --limit 5 --query 'events[].message' --output text
    } catch {
        # Logs may not be available yet
    }
} while ($status -ne "STOPPED")

# Check final result
$taskDetails = aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $TASK_ARN --region $AWS_REGION | ConvertFrom-Json
$exitCode = $taskDetails.tasks[0].containers[0].exitCode

if ($exitCode -eq 0) {
    Write-Host "`n[SUCCESS] Database initialization successful!" -ForegroundColor Green
    
    # Check for Airflow tables
    Write-Host "`nVerifying Airflow tables..." -ForegroundColor Yellow
    psql -h $DB_ENDPOINT -U airflow -d airflow -c "\dt"
    
    # Check if main service is running
    Write-Host "`nAirflow should now be able to start properly." -ForegroundColor Green
    Write-Host "You can access the Airflow UI at: http://$(terraform output -raw airflow_ui_url)" -ForegroundColor Green
} else {
    Write-Host "`n[ERROR] Database initialization failed with exit code: $exitCode" -ForegroundColor Red
    
    # Display logs
    Write-Host "Retrieving logs..." -ForegroundColor Yellow
    aws logs get-log-events --log-group-name "/ecs/airflow" --log-stream-name "ecs-db-upgrade/airflow-db-upgrade/$TASK_ID" --region $AWS_REGION --limit 50 --query 'events[].message' --output text
    
    # As a last resort, try to initialize using PostgreSQL directly
    $tryDirectSql = Read-Host "Do you want to try direct SQL initialization as a last resort? (y/n)"
    if ($tryDirectSql -eq "y") {
        Write-Host "This method is experimental and may not work correctly." -ForegroundColor Yellow
        Write-Host "Creating minimal database structure..." -ForegroundColor Yellow
        
        # Create absolute minimum tables needed for Airflow to start
        $sql = @"
        CREATE TABLE IF NOT EXISTS alembic_version (
            version_num VARCHAR(32) NOT NULL, 
            CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num)
        );
        INSERT INTO alembic_version (version_num) VALUES ('e1a11ece99df') ON CONFLICT DO NOTHING;
        
        CREATE TABLE IF NOT EXISTS connection (
            id SERIAL PRIMARY KEY,
            conn_id VARCHAR(250) NOT NULL,
            conn_type VARCHAR(500) NOT NULL,
            host VARCHAR(500),
            schema VARCHAR(500),
            login VARCHAR(500),
            password VARCHAR(500),
            port INTEGER,
            extra VARCHAR(5000),
            is_encrypted BOOLEAN DEFAULT false,
            is_extra_encrypted BOOLEAN DEFAULT false,
            description TEXT,
            UNIQUE (conn_id)
        );
        
        CREATE TABLE IF NOT EXISTS variable (
            id SERIAL PRIMARY KEY,
            key VARCHAR(250) NOT NULL,
            val VARCHAR(5000),
            is_encrypted BOOLEAN DEFAULT false,
            description TEXT,
            UNIQUE (key)
        );
        
        CREATE TABLE IF NOT EXISTS dag (
            dag_id VARCHAR(250) NOT NULL,
            is_paused BOOLEAN DEFAULT false,
            is_active BOOLEAN DEFAULT true,
            last_parsed_time TIMESTAMP WITH TIME ZONE,
            last_pickled TIMESTAMP WITH TIME ZONE,
            last_expired TIMESTAMP WITH TIME ZONE,
            scheduler_lock BOOLEAN,
            pickle_id INTEGER,
            fileloc VARCHAR(2000),
            owners VARCHAR(2000),
            description TEXT,
            default_view VARCHAR(25),
            schedule_interval TEXT,
            root_dag_id VARCHAR(250),
            timetable_description VARCHAR(1000),
            tags TEXT,
            has_task_concurrency_limits BOOLEAN DEFAULT true,
            next_dagrun TIMESTAMP WITH TIME ZONE,
            next_dagrun_create_after TIMESTAMP WITH TIME ZONE,
            max_active_tasks INTEGER DEFAULT 16,
            CONSTRAINT dag_pkey PRIMARY KEY (dag_id)
        );
"@
        
        # Run SQL directly
        $sql | psql -h $DB_ENDPOINT -U airflow -d airflow
        
        Write-Host "Minimal tables created. Try running the Airflow service now." -ForegroundColor Yellow
    }
} 