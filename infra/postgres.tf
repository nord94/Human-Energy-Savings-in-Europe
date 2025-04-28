resource "aws_db_subnet_group" "postgres_subnet_group" {
  name       = "postgres-subnet-group"
  subnet_ids = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Allow PostgreSQL access"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Postgres from Airflow ECS"
    protocol        = "tcp"
    from_port       = 5432
    to_port         = 5432
    security_groups = [aws_security_group.ecs_airflow.id]
  }

  ingress {
    description = "Postgres from VPC"
    protocol    = "tcp"
    from_port   = 5432
    to_port     = 5432
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "postgres" {
  identifier             = "airflow-postgres"
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "17.2"
  instance_class         = "db.t4g.micro"
  username               = "airflow"
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.postgres_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
  
  # Connection settings
  parameter_group_name = aws_db_parameter_group.airflow_postgres.name
  
  # Better connection management
  max_allocated_storage = 50  # Allow storage to grow if needed
  auto_minor_version_upgrade = true
  
  # Snapshot and backup configuration
  backup_retention_period = 1
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:00:00-Mon:02:00"
  
  # Performance insights (free tier compatible)
  performance_insights_enabled = true
  performance_insights_retention_period = 7
  
  # Add apply_immediately to handle parameter changes right away
  apply_immediately = true

  # Add dependency on parameter group
  depends_on = [
    aws_db_parameter_group.airflow_postgres
  ]
}

resource "aws_db_parameter_group" "airflow_postgres" {
  name   = "airflow-postgres-params"
  family = "postgres17"

  parameter {
    name  = "max_connections"
    value = "100"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "statement_timeout"
    value = "300000"  # 5 minutes in milliseconds
  }

  parameter {
    name  = "idle_in_transaction_session_timeout"
    value = "300000"  # 5 minutes in milliseconds
  }
}

