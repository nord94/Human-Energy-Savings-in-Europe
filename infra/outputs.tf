output "airflow_db_endpoint" {
  value = aws_db_instance.postgres.address
}

output "airflow_db_identifier" {
  value = aws_db_instance.postgres.identifier
}

output "airflow_ui_url" {
  value = aws_lb.airflow_lb.dns_name
}

# This is safe only for development environments
output "db_password" {
  value     = var.db_password
  sensitive = true
}

# Outputs for run_db_upgrade.sh script
output "aws_region" {
  value = var.aws_region
}

output "airflow_cluster_name" {
  value = aws_ecs_cluster.airflow_cluster.name
}

output "airflow_db_upgrade_task_arn" {
  value = aws_ecs_task_definition.airflow_db_upgrade.arn
}

output "public_subnet_a_id" {
  value = aws_subnet.public_a.id
}

output "public_subnet_b_id" {
  value = aws_subnet.public_b.id
}

output "ecs_security_group_id" {
  value = aws_security_group.ecs_airflow.id
}

