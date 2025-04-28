resource "aws_ecs_cluster" "airflow_cluster" {
  name = "airflow-ecs-cluster"
}

resource "aws_ecs_task_definition" "airflow" {
  family                   = "airflow-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"

  container_definitions = jsonencode([{
    name  = "airflow-webserver"
    image = "apache/airflow:latest"
    portMappings = [{
      containerPort = 8080
      hostPort      = 8080
    }]
    environment = [
      {"name": "AIRFLOW__CORE__SQL_ALCHEMY_CONN", "value": "postgresql+psycopg2://airflow:yourStrongPassword@${aws_db_instance.postgres.address}:5432/airflow"}
    ]
  }])
}

resource "aws_ecs_service" "airflow_service" {
  name            = "airflow-service"
  cluster         = aws_ecs_cluster.airflow_cluster.id
  task_definition = aws_ecs_task_definition.airflow.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public.id]
    assign_public_ip = true
    security_groups  = [aws_security_group.ecs_airflow.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.airflow_tg.arn
    container_name   = "airflow-webserver"
    container_port   = 8080
  }
}

resource "aws_security_group" "ecs_airflow" {
  name        = "ecs-airflow-sg"
  description = "Allow Airflow ECS inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "HTTP traffic"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

