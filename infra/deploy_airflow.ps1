# Comprehensive Airflow Deployment Script
# This script handles the entire deployment process for Airflow on AWS

Write-Host "=== AIRFLOW DEPLOYMENT SCRIPT ===" -ForegroundColor Cyan
Write-Host "This script will deploy and initialize your Airflow infrastructure on AWS" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Check prerequisites
Write-Host "`nChecking prerequisites..." -ForegroundColor Yellow

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

# Check if Terraform is installed
try {
    $terraformVersion = terraform --version
    Write-Host "* Terraform is available" -ForegroundColor Green
} catch {
    Write-Host "X ERROR: Terraform is not installed or not in your PATH!" -ForegroundColor Red
    Write-Host "  Please install Terraform from: https://www.terraform.io/downloads.html" -ForegroundColor Red
    exit 1
}

# Step 1: Apply Terraform Changes
Write-Host "`n[STEP 1] Applying Terraform configuration..." -ForegroundColor Cyan

# Initialize Terraform
Write-Host "Initializing Terraform..." -ForegroundColor Yellow
terraform init

if ($LASTEXITCODE -ne 0) {
    Write-Host "X Terraform initialization failed!" -ForegroundColor Red
    exit 1
}

# Apply Terraform configuration
Write-Host "Applying Terraform configuration..." -ForegroundColor Yellow
terraform apply

if ($LASTEXITCODE -ne 0) {
    Write-Host "X Terraform apply failed!" -ForegroundColor Red
    Write-Host "Please check the error messages above and fix any issues." -ForegroundColor Yellow
    exit 1
}

Write-Host "* Terraform applied successfully!" -ForegroundColor Green

# Step 2: Reboot Database (if parameter group was updated)
Write-Host "`n[STEP 2] Rebooting database to apply parameter changes..." -ForegroundColor Cyan
Write-Host "Note: This step is required for some PostgreSQL parameters like max_connections" -ForegroundColor Yellow

$rebootConfirm = Read-Host "Do you want to reboot the database? (y/n)"
if ($rebootConfirm -eq "y") {
    & .\reboot_db.ps1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "X Database reboot failed!" -ForegroundColor Red
        Write-Host "You may need to reboot the database manually in the AWS console." -ForegroundColor Yellow
    }
} else {
    Write-Host "Skipping database reboot..." -ForegroundColor Yellow
}

# Step 3: Run Database Upgrade Task
Write-Host "`n[STEP 3] Running Airflow database initialization task..." -ForegroundColor Cyan

$runDbUpgrade = Read-Host "Do you want to run the database upgrade task now? (y/n)"
if ($runDbUpgrade -eq "y") {
    & .\run_db_upgrade.ps1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "X Database upgrade task failed!" -ForegroundColor Red
        Write-Host "Please check the logs above for errors." -ForegroundColor Yellow
        
        # Offer alternative method
        Write-Host "The most common error is: TypeError: create_engine() got multiple values for keyword argument 'connect_args'" -ForegroundColor Yellow
        $tryChoice = Read-Host "Which alternative would you like to try? (1=simplified connection, 2=direct DB init, 3=skip)"
        if ($tryChoice -eq "1") {
            & .\fix_db_connection.ps1
        } elseif ($tryChoice -eq "2") {
            & .\direct_db_init.ps1
        } else {
            # Offer to check database connectivity
            $checkDb = Read-Host "Do you want to check database connectivity? (y/n)"
            if ($checkDb -eq "y") {
                & .\db_connect.ps1
            }
        }
        
        exit 1
    }
} else {
    Write-Host "Skipping database upgrade task..." -ForegroundColor Yellow
    Write-Host "You can run it later with: .\run_db_upgrade.ps1" -ForegroundColor Yellow
}

# Step 4: Verify Airflow UI Availability
Write-Host "`n[STEP 4] Verifying Airflow UI availability..." -ForegroundColor Cyan
Write-Host "Note: It may take 5-10 minutes for the Airflow service to start up fully" -ForegroundColor Yellow

$airflowUrl = terraform output -raw airflow_ui_url
Write-Host "Airflow UI will be available at: http://$airflowUrl" -ForegroundColor Green
Write-Host "Default login credentials:" -ForegroundColor Green
Write-Host "  Username: admin" -ForegroundColor Green
Write-Host "  Password: admin" -ForegroundColor Green

Write-Host "`n=== DEPLOYMENT COMPLETE ===" -ForegroundColor Cyan
Write-Host "If you encounter any issues, refer to TROUBLESHOOTING.md" -ForegroundColor Yellow 