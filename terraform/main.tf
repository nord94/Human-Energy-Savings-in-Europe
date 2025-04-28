provider "aws" {
  region = "eu-central-1"
}

# VPC and networking resources
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  
  name = "airflow-vpc"
  cidr = "10.0.0.0/16"
  
  azs             = ["eu-central-1a", "eu-central-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
  
  enable_nat_gateway = true
  single_nat_gateway = true
  
  tags = {
    Terraform   = "true"
    Environment = "dev"
    Project     = "Human-Energy-Savings-in-Europe"
  }
}

# Security groups
resource "aws_security_group" "ecs_sg" {
  name        = "airflow-ecs-sg"
  description = "Allow inbound traffic to ECS"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "airflow-ecs-sg"
  }
}

resource "aws_security_group" "db_sg" {
  name        = "airflow-db-sg"
  description = "Allow inbound traffic to RDS from ECS"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "airflow-db-sg"
  }
}

# ECR Repositories for our Docker images
resource "aws_ecr_repository" "airflow" {
  name                 = "airflow"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "postgres" {
  name                 = "postgres"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "airflow_cluster" {
  name = "airflow-ecs-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "airflow-ecs-cluster"
  }
}

# IAM role for ECS task execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# RDS PostgreSQL instance
resource "aws_db_subnet_group" "airflow" {
  name       = "airflow-db-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name = "airflow-db-subnet-group"
  }
}

resource "aws_db_instance" "postgres" {
  identifier             = "airflow-postgres"
  engine                 = "postgres"
  engine_version         = "14"
  instance_class         = "db.t3.small"
  allocated_storage      = 20
  storage_type           = "gp2"
  username               = "airflow"
  password               = "yourStrongPassword" # Replace with a secure password
  db_name                = "airflow"
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.airflow.name
  skip_final_snapshot    = true
  
  tags = {
    Name = "airflow-postgres"
  }
}

# ECS Task Definition for Airflow
resource "aws_ecs_task_definition" "airflow" {
  family                   = "airflow-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  
  container_definitions = jsonencode([
    {
      name              = "airflow-webserver"
      image             = "${aws_ecr_repository.airflow.repository_url}:latest"
      essential         = true
      command           = ["webserver"]
      cpu               = 1024
      memory            = 2048
      logConfiguration  = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/airflow"
          "awslogs-region"        = "eu-central-1"
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
        }
      }
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "AIRFLOW__CORE__SQL_ALCHEMY_CONN"
          value = "postgresql+psycopg2://airflow:yourStrongPassword@${aws_db_instance.postgres.endpoint}/airflow"
        },
        {
          name  = "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN"
          value = "postgresql+psycopg2://airflow:yourStrongPassword@${aws_db_instance.postgres.endpoint}/airflow"
        },
        {
          name  = "AIRFLOW__WEBSERVER__WEB_SERVER_PORT"
          value = "8080"
        },
        {
          name  = "AIRFLOW__WEBSERVER__ENABLE_PROXY_FIX"
          value = "True"
        },
        {
          name  = "AIRFLOW__LOGGING__LOGGING_LEVEL"
          value = "INFO"
        }
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name = "airflow-task"
  }
}

# ALB for Airflow
resource "aws_lb" "airflow" {
  name               = "airflow-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ecs_sg.id]
  subnets            = module.vpc.public_subnets

  tags = {
    Name = "airflow-alb"
  }
}

resource "aws_lb_target_group" "airflow" {
  name        = "airflow-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    path                = "/health"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name = "airflow-tg"
  }
}

resource "aws_lb_listener" "airflow" {
  load_balancer_arn = aws_lb.airflow.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.airflow.arn
  }
}

# ECS Service
resource "aws_ecs_service" "airflow" {
  name            = "airflow-service"
  cluster         = aws_ecs_cluster.airflow_cluster.id
  task_definition = aws_ecs_task_definition.airflow.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.public_subnets
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.airflow.arn
    container_name   = "airflow-webserver"
    container_port   = 8080
  }

  depends_on = [
    aws_lb_listener.airflow,
    aws_db_instance.postgres
  ]

  tags = {
    Name = "airflow-service"
  }
} 