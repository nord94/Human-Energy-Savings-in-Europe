# Airflow Database Troubleshooting Guide

This guide will help you resolve issues with the Airflow database initialization process.

## Issue: Database Initialization Takes Too Long

If your Airflow database initialization task is running longer than expected or failing, follow these steps to diagnose and fix the issue.

## Step 1: Apply Infrastructure Changes

First, apply the updated infrastructure with the enhancements to the database and task configurations:

```bash
cd infra
terraform apply
```

If the `terraform apply` command shows an error related to the parameter group, you need to reboot the database instance to apply the parameter changes:

```powershell
# Run the reboot script
.\reboot_db.ps1
```

The script will monitor the reboot process and notify you when the database is available again.

## Step 2: Run the Enhanced DB Upgrade Task

Use the provided PowerShell script to run the enhanced DB upgrade task with real-time monitoring:

```powershell
.\run_db_upgrade.ps1
```

This script will:
- Start the Airflow DB upgrade task with proper timeouts (Fargate requires < 120 seconds)
- Monitor the status in real-time
- Display log messages as they come in
- Provide detailed error information if the task fails

## Common Errors and Solutions

### TypeError: create_engine() got multiple values for keyword argument 'connect_args'

If you see this error in the logs:

```
TypeError: create_engine() got multiple values for keyword argument 'connect_args'
```

There are three solutions to try, in order of preference:

1. **First Solution**: Use the simplified connection script:

```powershell
.\fix_db_connection.ps1
```

2. **Alternate Solution**: Use the direct database initialization approach (bypasses Airflow's initialization):

```powershell
.\direct_db_init.ps1
```

This script:
- Creates the database directly using PostgreSQL client
- Uses a custom airflow.cfg to avoid any SQLAlchemy conflicts
- Contains a fallback to create minimal tables directly with SQL if needed

3. **Manual Database Creation**: If the above methods fail, you can manually set up the database:

```powershell
$env:PGPASSWORD = terraform output -raw db_password
psql -h $(terraform output -raw airflow_db_endpoint) -U airflow -d postgres -c "CREATE DATABASE airflow;"
```

### Permission Issues or Connection Timeouts

If the DB upgrade task fails due to connection or permission issues:

1. Check database connectivity using the diagnostic script:

```powershell
.\db_connect.ps1
```

2. Ensure the security groups allow traffic from the ECS task to the database (port 5432)

3. Verify the database user has proper permissions:

```sql
GRANT ALL PRIVILEGES ON DATABASE airflow TO airflow;
```

### Fargate Timeout Constraints

Remember that Fargate requires container stop timeouts to be less than 120 seconds. Our configuration uses:
- 119 seconds for the container stop timeout
- 90 seconds for each database command via the Linux `timeout` utility

## Manual Database Setup

If automated methods fail, the `direct_db_init.ps1` script will offer to create a minimal set of tables directly. This is sufficient for Airflow to start up, but may cause issues with some advanced features.

For a more complete setup, you will need to run the full Airflow initialization command on a system with direct database access. 