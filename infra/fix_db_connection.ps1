# Script to run a simplified database initialization task with fixed connection parameters

# Check if AWS CLI is installed
try {
    $awsVersion = aws --version
    Write-Host "* AWS CLI is available: $awsVersion" -ForegroundColor Green
} catch {
    Write-Host "X ERROR: AWS CLI is not installed or not in your PATH!" -ForegroundColor Red
    Write-Host "  Please install AWS CLI from: https://aws.amazon.com/cli/" -ForegroundColor Red
    Write-Host "  After installation, configure your AWS credentials with: aws configure" -ForegroundColor Yellow
    exit 1
}

# Load AWS configuration from Terraform output
$AWS_REGION = terraform output -raw aws_region
$CLUSTER_NAME = terraform output -raw airflow_cluster_name
$TASK_DEF_ARN = terraform output -raw airflow_db_upgrade_task_arn
$SUBNET_A = terraform output -raw public_subnet_a_id
$SUBNET_B = terraform output -raw public_subnet_b_id
$SG_ID = terraform output -raw ecs_security_group_id
$DB_ENDPOINT = terraform output -raw airflow_db_endpoint
$DB_PASSWORD = terraform output -raw db_password 2>$null

if (-not $DB_PASSWORD) {
    $DB_PASSWORD = Read-Host "Enter your database password"
}

Write-Host "Running a simplified Airflow database initialization task..." -ForegroundColor Cyan
Write-Host "Using simplified connection parameters to avoid connect_args conflicts" -ForegroundColor Yellow

# Prepare environment variables with simplified config - removing all engine args
$ENV_VARS = @(
    "{""name"":""AIRFLOW__CORE__SQL_ALCHEMY_CONN"",""value"":""postgresql+psycopg2://airflow:$DB_PASSWORD@$DB_ENDPOINT/airflow""}",
    "{""name"":""AIRFLOW__DATABASE__SQL_ALCHEMY_CONN"",""value"":""postgresql+psycopg2://airflow:$DB_PASSWORD@$DB_ENDPOINT/airflow""}",
    "{""name"":""AIRFLOW__LOGGING__LOGGING_LEVEL"",""value"":""DEBUG""}",
    "{""name"":""PYTHONPATH"",""value"":""/opt/airflow""}",
    "{""name"":""AIRFLOW_HOME"",""value"":""/opt/airflow""}",
    "{""name"":""AIRFLOW__DATABASE__SQL_ALCHEMY_ENGINE_ARGS"",""value"":""{}""}"
)

$ENV_JSON = "[" + ($ENV_VARS -join ",") + "]"

# Run a task with simplified init command
try {
    Write-Host "Running airflow db init task with simplified configuration..." -ForegroundColor Cyan
    
    $runTaskCommand = "aws ecs run-task " + `
        "--cluster $CLUSTER_NAME " + `
        "--task-definition $TASK_DEF_ARN " + `
        "--launch-type FARGATE " + `
        "--network-configuration ""awsvpcConfiguration={subnets=[$SUBNET_A,$SUBNET_B],securityGroups=[$SG_ID],assignPublicIp=ENABLED}"" " + `
        "--overrides ""{""""containerOverrides"""":[{""""name"""":""""airflow-db-upgrade"""",""""command"""":[""""bash"""",""""""-c"""""""",""""set -ex; sleep 5; timeout 90 airflow db init""""],""""environment"""":$ENV_JSON}]}"" " + `
        "--region $AWS_REGION"
        
    # Show the command for debug purposes
    Write-Host "Command: $runTaskCommand" -ForegroundColor DarkGray
    
    # Run the command and capture the output
    $taskOutput = Invoke-Expression $runTaskCommand | ConvertFrom-Json
    
    if (-not $taskOutput) {
        throw "Failed to start task. Check your AWS credentials and permissions."
    }
    
    $TASK_ARN = $taskOutput.tasks[0].taskArn
    $TASK_ID = $TASK_ARN.Split('/')[-1]
    
    Write-Host "Task started with ARN: $TASK_ARN" -ForegroundColor Green
    
    # Monitor task status
    $status = "PENDING"
    do {
        Start-Sleep -Seconds 5
        $status = aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $TASK_ARN --region $AWS_REGION --query 'tasks[0].lastStatus' --output text
        Write-Host "Current status: $status" -ForegroundColor Yellow
        
        # Try to get any available logs
        try {
            aws logs get-log-events --log-group-name "/ecs/airflow" --log-stream-name "ecs-db-upgrade/airflow-db-upgrade/$TASK_ID" --region $AWS_REGION --limit 5 --query 'events[].message' --output text
        } catch {
            # Logs may not be available yet
        }
    } while ($status -ne "STOPPED")
    
    # Get final results
    $taskDetails = aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $TASK_ARN --region $AWS_REGION | ConvertFrom-Json
    $exitCode = $taskDetails.tasks[0].containers[0].exitCode
    
    if ($exitCode -eq 0) {
        Write-Host "✅ Database initialization successful!" -ForegroundColor Green
        
        # Try to run an upgrade now
        $runUpgrade = Read-Host "Do you want to run 'airflow db upgrade' now? (y/n)"
        if ($runUpgrade -eq "y") {
            $upgradeCmd = "aws ecs run-task " + `
                "--cluster $CLUSTER_NAME " + `
                "--task-definition $TASK_DEF_ARN " + `
                "--launch-type FARGATE " + `
                "--network-configuration ""awsvpcConfiguration={subnets=[$SUBNET_A,$SUBNET_B],securityGroups=[$SG_ID],assignPublicIp=ENABLED}"" " + `
                "--overrides ""{""""containerOverrides"""":[{""""name"""":""""airflow-db-upgrade"""",""""command"""":[""""bash"""",""""""-c"""""""",""""set -ex; sleep 5; timeout 90 airflow db upgrade""""],""""environment"""":$ENV_JSON}]}"" " + `
                "--region $AWS_REGION"
                
            Invoke-Expression $upgradeCmd | Out-Null
            Write-Host "Upgrade task started. Check AWS console for task status." -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ Database initialization failed with exit code: $exitCode" -ForegroundColor Red
        
        # Get all logs
        Write-Host "Retrieving all logs..." -ForegroundColor Yellow
        $logs = aws logs get-log-events --log-group-name "/ecs/airflow" --log-stream-name "ecs-db-upgrade/airflow-db-upgrade/$TASK_ID" --region $AWS_REGION --limit 50 | ConvertFrom-Json
        
        Write-Host "=== FULL LOG OUTPUT ===" -ForegroundColor DarkYellow
        foreach ($event in $logs.events) {
            Write-Host $event.message -ForegroundColor Gray
        }
        Write-Host "=== END OF LOG ===" -ForegroundColor DarkYellow
        
        # Check database connectivity
        $checkDb = Read-Host "Do you want to check database connectivity? (y/n)"
        if ($checkDb -eq "y") {
            & .\db_connect.ps1
        }
    }
} catch {
    Write-Host "Error running task: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
} 