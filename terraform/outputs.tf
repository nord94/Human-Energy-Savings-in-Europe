output "airflow_load_balancer_dns" {
  description = "DNS name of the Airflow load balancer"
  value       = aws_lb.airflow.dns_name
}

output "ecr_airflow_repository_url" {
  description = "URL of the ECR repository for Airflow"
  value       = aws_ecr_repository.airflow.repository_url
}

output "ecr_postgres_repository_url" {
  description = "URL of the ECR repository for PostgreSQL"
  value       = aws_ecr_repository.postgres.repository_url
}

output "rds_endpoint" {
  description = "Endpoint of the RDS instance"
  value       = aws_db_instance.postgres.endpoint
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.airflow_cluster.name
} 