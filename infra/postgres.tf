resource "aws_db_subnet_group" "postgres_subnet_group" {
  name       = "postgres-subnet-group"
  subnet_ids = [aws_subnet.public.id]
}

resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Allow PostgreSQL access"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "Postgres from Airflow ECS"
    protocol         = "tcp"
    from_port        = 5432
    to_port          = 5432
    cidr_blocks      = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "postgres" {
  identifier              = "airflow-postgres"
  allocated_storage       = 20
  engine                  = "postgres"
  engine_version          = "15.4"
  instance_class          = "db.t4g.micro"
  username                = "airflow"
  password                = "yourStrongPassword"
  db_subnet_group_name    = aws_db_subnet_group.postgres_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  publicly_accessible     = false
  skip_final_snapshot     = true
}

