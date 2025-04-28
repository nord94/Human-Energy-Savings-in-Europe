# PowerShell script to reboot RDS instance to apply parameter group changes

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
$DB_IDENTIFIER = terraform output -raw airflow_db_identifier
$DB_ENDPOINT = terraform output -raw airflow_db_endpoint

Write-Host "Rebooting RDS instance $DB_IDENTIFIER to apply parameter group changes..." -ForegroundColor Yellow

# Reboot the RDS instance
try {
    aws rds reboot-db-instance --db-instance-identifier $DB_IDENTIFIER --region $AWS_REGION
    
    Write-Host "Reboot command sent successfully. Waiting for instance to become available..." -ForegroundColor Cyan
    
    # Monitor the DB instance status
    $status = ""
    do {
        Start-Sleep -Seconds 10
        $status = aws rds describe-db-instances --db-instance-identifier $DB_IDENTIFIER --region $AWS_REGION --query 'DBInstances[0].DBInstanceStatus' --output text
        Write-Host "Current status: $status" -ForegroundColor Yellow
    } while ($status -ne "available")
    
    Write-Host "Database instance is now available." -ForegroundColor Green
    Write-Host "DB Endpoint: $DB_ENDPOINT" -ForegroundColor Green
} catch {
    Write-Host "Error rebooting database: $_" -ForegroundColor Red
    exit 1
} 