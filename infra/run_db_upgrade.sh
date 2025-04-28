#!/bin/bash

# Load AWS configuration from Terraform output
AWS_REGION=$(terraform output -raw aws_region)
CLUSTER_NAME=$(terraform output -raw airflow_cluster_name)
TASK_DEF_ARN=$(terraform output -raw airflow_db_upgrade_task_arn)
SUBNET_A=$(terraform output -raw public_subnet_a_id)
SUBNET_B=$(terraform output -raw public_subnet_b_id)
SG_ID=$(terraform output -raw ecs_security_group_id)

echo "Running Airflow DB upgrade task with increased timeout..."

# Run the task
TASK_ARN=$(aws ecs run-task \
  --cluster $CLUSTER_NAME \
  --task-definition $TASK_DEF_ARN \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_A,$SUBNET_B],securityGroups=[$SG_ID],assignPublicIp=ENABLED}" \
  --region $AWS_REGION \
  --query 'tasks[0].taskArn' \
  --output text)

echo "Task started with ARN: $TASK_ARN"
echo "Waiting for task to complete..."

# Monitor task status
aws ecs wait tasks-stopped --cluster $CLUSTER_NAME --tasks $TASK_ARN --region $AWS_REGION

# Get the task details after completion
echo "Task completed. Checking status..."
EXIT_CODE=$(aws ecs describe-tasks \
  --cluster $CLUSTER_NAME \
  --tasks $TASK_ARN \
  --region $AWS_REGION \
  --query 'tasks[0].containers[0].exitCode' \
  --output text)

if [ "$EXIT_CODE" == "0" ]; then
  echo "Database upgrade completed successfully!"
else
  echo "Database upgrade failed with exit code: $EXIT_CODE"
  echo "Retrieving logs..."
  
  # Get the task ID from the ARN
  TASK_ID=$(echo $TASK_ARN | cut -d'/' -f3)
  
  # Get logs from CloudWatch
  aws logs get-log-events \
    --log-group-name "/ecs/airflow" \
    --log-stream-name "ecs-db-upgrade/airflow-db-upgrade/$TASK_ID" \
    --region $AWS_REGION \
    --query 'events[*].message' \
    --output text
fi 