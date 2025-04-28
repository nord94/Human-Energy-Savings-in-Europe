variable "aws_region" {
  default = "eu-central-1"
}

variable "db_password" {
  type        = string
  description = "PostgreSQL password for Airflow database"
  sensitive   = true
}

