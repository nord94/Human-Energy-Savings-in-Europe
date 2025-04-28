resource "aws_cloudwatch_log_group" "airflow_log_group" {
  name              = "/ecs/airflow"
  retention_in_days = 7
}
