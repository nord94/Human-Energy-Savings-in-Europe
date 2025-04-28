# Airflow Deployment Steps

Follow these steps to deploy and initialize your Airflow infrastructure in AWS:

## Prerequisites

Before you begin, make sure you have:

1. **AWS CLI** installed and configured with credentials:
   - Download from: https://aws.amazon.com/cli/
   - Run `aws configure` to set up your credentials

2. **Terraform** installed:
   - Download from: https://www.terraform.io/downloads.html

3. **PostgreSQL Client** (optional, for database diagnostics):
   - Download from: https://www.postgresql.org/download/windows/

## Quick Start (Automated Deployment)

For a guided deployment process, use the all-in-one deployment script:

```powershell
# Run from the infra directory
.\deploy_airflow.ps1
```

This script will:
1. Check for required prerequisites
2. Initialize and apply Terraform configurations
3. Guide you through database reboot and upgrade steps
4. Provide the URL to access the Airflow UI when ready

## Manual Deployment Steps

If you prefer to run the deployment steps individually, follow the instructions below:

## 1. Apply Terraform Configuration

```powershell
# Change to the infrastructure directory
cd infra

# Initialize Terraform (if not already done)
terraform init

# Apply the changes
terraform apply
```

When prompted, enter your database password.

## 2. Reboot Database to Apply Parameter Changes

```powershell
# Run the reboot script
.\reboot_db.ps1
```

This is needed for static parameters like `max_connections` to take effect. The script will monitor the reboot process and notify you when the database is back online.

## 3. Run the Database Initialization Task

```powershell
# Run the DB initialization script
.\run_db_upgrade.ps1
```

This script will:
1. Launch the Airflow DB upgrade task
2. Show real-time task status
3. Display logs as they come in
4. Notify you when the task completes

If you encounter errors, try these alternatives in order:

1. **For 'connect_args' conflicts**:
   ```powershell
   # Alternative script with simplified connection parameters
   .\fix_db_connection.ps1
   ```

2. **For persistent initialization failures**:
   ```powershell
   # Direct database initialization bypassing Airflow's built-in process
   .\direct_db_init.ps1
   ```
   This approach creates the database directly using PostgreSQL and runs a minimal initialization with a custom configuration.

## 4. Verify Database Connectivity

```powershell
# Check database connectivity and status
.\db_connect.ps1
```

This will verify that:
- The database is accessible
- The Airflow database exists
- Tables have been created properly

## 5. Wait for Airflow Service to Start

After the database is properly initialized, the main Airflow service will start automatically. Allow 5-10 minutes for this process to complete.

## 6. Access Airflow UI

When deployment is complete, you can access the Airflow UI at:

```
http://$(terraform output -raw airflow_ui_url)
```

Default login credentials:
- Username: `admin`
- Password: `admin`

## Troubleshooting

If you encounter any issues during deployment, refer to `TROUBLESHOOTING.md` for detailed steps to resolve common problems.

For database-specific issues:
```powershell
# Check database status
.\db_connect.ps1
```

For task-specific issues:
```powershell
# View task logs in real-time
.\run_db_upgrade.ps1
``` 