resource "aws_ecs_service" "airflow_service" {
  name            = "airflow-service"
  cluster         = aws_ecs_cluster.airflow_cluster.id
  task_definition = aws_ecs_task_definition.airflow.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    assign_public_ip = true
    security_groups  = [aws_security_group.ecs_airflow.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.airflow_tg.arn
    container_name   = "airflow-webserver"
    container_port   = 8080
  }

  depends_on = [
    aws_lb_listener.airflow_listener
  ]
}

# ECS Cluster definition
resource "aws_ecs_cluster" "airflow_cluster" {
  name = "airflow-ecs-cluster"
}

# ECS Task Definition for Airflow
resource "aws_ecs_task_definition" "airflow" {
  family                   = "airflow-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "airflow-webserver"
      image     = "apache/airflow:2.8.1"
      essential = true
      command   = ["webserver"]
      portMappings = [{
        containerPort = 8080
        hostPort      = 8080
      }]
      environment = [
        {
          name  = "AIRFLOW__CORE__SQL_ALCHEMY_CONN",
          value = "postgresql+psycopg2://airflow:${var.db_password}@${aws_db_instance.postgres.address}:5432/airflow"
        },
        {
          name  = "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN", 
          value = "postgresql+psycopg2://airflow:${var.db_password}@${aws_db_instance.postgres.address}:5432/airflow"
        },
        {
          name  = "AIRFLOW__WEBSERVER__WEB_SERVER_PORT",
          value = "8080"
        },
        {
          name  = "AIRFLOW__WEBSERVER__ENABLE_PROXY_FIX", 
          value = "True"
        },
        {
          name  = "AIRFLOW__LOGGING__LOGGING_LEVEL",
          value = "INFO"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/airflow"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
          awslogs-create-group  = "true"
        }
      }
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  depends_on = [
    aws_db_instance.postgres
  ]
}

resource "aws_ecs_task_definition" "airflow_db_upgrade" {
  family                   = "airflow-db-upgrade-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"  # Increased from 512
  memory                   = "2048"  # Increased from 1024
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  
  # Add task role for extended permissions
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn
  
  # Add specific Fargate platform version for stability
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
  
  container_definitions = jsonencode([
    {
      name      = "airflow-db-upgrade"
      image     = "apache/airflow:2.8.1"
      command   = [
        "bash", 
        "-c", 
        "set -ex; sleep 5; timeout 90 airflow db check || (echo 'Initializing database...' && timeout 90 airflow db init && echo 'Database initialized successfully'); echo 'Running db upgrade...'; timeout 90 airflow db upgrade && echo 'Database upgrade completed successfully'"
      ]
      essential = true
      stopTimeout = 119  # Must be less than 120 seconds for Fargate
      
      # Resource limits
      cpu         = 1024
      memory      = 2048
      
      environment = [
        {
          name  = "AIRFLOW__CORE__SQL_ALCHEMY_CONN",
          value = "postgresql+psycopg2://airflow:${var.db_password}@${aws_db_instance.postgres.address}:5432/airflow"
        },
        {
          name  = "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN", 
          value = "postgresql+psycopg2://airflow:${var.db_password}@${aws_db_instance.postgres.address}:5432/airflow"
        },
        {
          name  = "AIRFLOW__LOGGING__LOGGING_LEVEL",
          value = "DEBUG"
        },
        {
          name  = "AIRFLOW__API__LOG_FETCH_TIMEOUT_SEC", 
          value = "60"
        },
        {
          name  = "AIRFLOW__DATABASE__SQL_ALCHEMY_ENGINE_ARGS",
          value = "{\"connect_timeout\":60}"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/airflow"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs-db-upgrade"
          awslogs-create-group  = "true"
        }
      }
    }
  ])

  depends_on = [
    aws_db_instance.postgres
  ]
}

# Instead, use the PowerShell script to run the DB upgrade task:
# .\run_db_upgrade.ps1

resource "aws_security_group" "ecs_airflow" {
  name        = "ecs-airflow-sg"
  description = "Allow Airflow ECS inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow Airflow HTTP inbound"
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
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

