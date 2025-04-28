# PowerShell script to run Airflow DB upgrade task with enhanced monitoring

# Check if AWS CLI is installed
try {
    $awsVersion = aws --version
    Write-Host "* AWS CLI is available: $awsVersion" -ForegroundColor Green
} catch {
    Write-Host "X ERROR: AWS CLI is not installed or not in your PATH!" -ForegroundColor Red
    Write-Host "  Please install AWS CLI from: https://aws.amazon.com/cli/" -ForegroundColor Red
    Write-Host "After installation, configure your AWS credentials with: aws configure" -ForegroundColor Yellow
    exit 1
}

# Load AWS configuration from Terraform output
$AWS_REGION = terraform output -raw aws_region
$CLUSTER_NAME = terraform output -raw airflow_cluster_name
$TASK_DEF_ARN = terraform output -raw airflow_db_upgrade_task_arn
$SUBNET_A = terraform output -raw public_subnet_a_id
$SUBNET_B = terraform output -raw public_subnet_b_id
$SG_ID = terraform output -raw ecs_security_group_id

Write-Host "Running Airflow DB upgrade task with enhanced monitoring..." -ForegroundColor Cyan

# Run the task
try {
    $TASK_ARN = aws ecs run-task `
      --cluster $CLUSTER_NAME `
      --task-definition $TASK_DEF_ARN `
      --launch-type FARGATE `
      --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_A,$SUBNET_B],securityGroups=[$SG_ID],assignPublicIp=ENABLED}" `
      --region $AWS_REGION `
      --query 'tasks[0].taskArn' `
      --output text

    if (-not $TASK_ARN) {
        throw "Failed to start task. Check your AWS credentials and permissions."
    }

    Write-Host "Task started with ARN: $TASK_ARN" -ForegroundColor Green
    
    # Get the task ID from the ARN for log monitoring
    $TASK_ID = $TASK_ARN.Split('/')[-1]
    
    # Create log group if it doesn't exist
    try {
        aws logs create-log-group --log-group-name "/ecs/airflow" --region $AWS_REGION
        Write-Host "Created log group: /ecs/airflow" -ForegroundColor Gray
    } catch {
        Write-Host "Log group already exists or couldn't be created (this is usually safe to ignore)" -ForegroundColor Gray
    }

    Write-Host "Monitoring task status and logs..." -ForegroundColor Cyan
    
    # Monitor task status and show logs in real-time
    $status = "PROVISIONING"
    $lastEventTime = 0
    
    while ($status -ne "STOPPED") {
        Start-Sleep -Seconds 5
        
        # Get current status
        $status = aws ecs describe-tasks `
            --cluster $CLUSTER_NAME `
            --tasks $TASK_ARN `
            --region $AWS_REGION `
            --query 'tasks[0].lastStatus' `
            --output text
            
        Write-Host "Current status: $status" -ForegroundColor Yellow
        
        # Try to get logs (they might not be available immediately)
        try {
            $logs = aws logs get-log-events `
                --log-group-name "/ecs/airflow" `
                --log-stream-name "ecs-db-upgrade/airflow-db-upgrade/$TASK_ID" `
                --start-from-head `
                --region $AWS_REGION `
                --next-token $null `
                --limit 20
                
            $events = $logs | ConvertFrom-Json
            
            if ($events.events.Count -gt 0) {
                foreach ($event in $events.events) {
                    if ($event.timestamp -gt $lastEventTime) {
                        Write-Host $event.message -ForegroundColor Gray
                        $lastEventTime = $event.timestamp
                    }
                }
            }
        } catch {
            # Logs may not be available yet
            Write-Host "Waiting for logs to become available..." -ForegroundColor DarkGray
        }
    }

    # Get the task details after completion
    Write-Host "Task completed. Checking final status..." -ForegroundColor Cyan
    $taskDetails = aws ecs describe-tasks `
      --cluster $CLUSTER_NAME `
      --tasks $TASK_ARN `
      --region $AWS_REGION | ConvertFrom-Json
    
    $container = $taskDetails.tasks[0].containers[0]
    $EXIT_CODE = $container.exitCode
    $reason = $taskDetails.tasks[0].stoppedReason

    if ($EXIT_CODE -eq 0) {
        Write-Host "✅ Database upgrade completed successfully!" -ForegroundColor Green
    } else {
        Write-Host "❌ Database upgrade failed with exit code: $EXIT_CODE" -ForegroundColor Red
        Write-Host "Reason: $reason" -ForegroundColor Red
        Write-Host "Retrieving all logs..." -ForegroundColor Yellow
        
        # Get all logs
        $allLogs = aws logs get-log-events `
            --log-group-name "/ecs/airflow" `
            --log-stream-name "ecs-db-upgrade/airflow-db-upgrade/$TASK_ID" `
            --start-from-head `
            --region $AWS_REGION `
            --limit 100 | ConvertFrom-Json
            
        Write-Host "=== FULL LOG OUTPUT ===" -ForegroundColor DarkYellow
        foreach ($event in $allLogs.events) {
            Write-Host $event.message -ForegroundColor Gray
        }
        Write-Host "=== END OF LOG ===" -ForegroundColor DarkYellow
    }
} catch {
    Write-Host "Error executing script: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
} 