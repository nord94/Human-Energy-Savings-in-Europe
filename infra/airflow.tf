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
      portMappings = [{
        containerPort = 8080
        hostPort      = 8080
      }]
      environment = [
        {
          name  = "AIRFLOW__CORE__SQL_ALCHEMY_CONN",
          value = "postgresql+psycopg2://airflow:${var.db_password}@${aws_db_instance.postgres.address}:5432/airflow"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/airflow"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "airflow_db_upgrade" {
  family                   = "airflow-db-upgrade-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "airflow-db-upgrade"
      image     = "apache/airflow:2.8.1"   # same version as your webserver
      command   = ["bash", "-c", "airflow db upgrade && sleep 10"]
      environment = [
        {
          name  = "AIRFLOW__CORE__SQL_ALCHEMY_CONN",
          value = "postgresql+psycopg2://airflow:${var.db_password}@${aws_db_instance.postgres.address}:5432/airflow"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/airflow"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

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

