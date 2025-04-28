variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-central-1"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "Human-Energy-Savings-in-Europe"
}

variable "db_username" {
  description = "Username for the RDS instance"
  type        = string
  default     = "airflow"
}

variable "db_password" {
  description = "Password for the RDS instance"
  type        = string
  sensitive   = true
  default     = "yourStrongPassword" # Don't use this in production, use AWS Secrets Manager or environment variables
}

variable "db_name" {
  description = "Name of the database"
  type        = string
  default     = "airflow"
} 