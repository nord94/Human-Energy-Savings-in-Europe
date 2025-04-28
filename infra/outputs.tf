output "airflow_db_endpoint" {
  value = aws_db_instance.postgres.address
}

output "airflow_ui_url" {
  value = aws_lb.airflow_lb.dns_name
}

