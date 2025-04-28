resource "aws_lb" "airflow_lb" {
  name               = "airflow-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ecs_airflow.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

resource "aws_lb_target_group" "airflow_tg" {
  name        = "airflow-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path = "/health"
  }
}

resource "aws_lb_listener" "airflow_listener" {
  load_balancer_arn = aws_lb.airflow_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.airflow_tg.arn
  }

  depends_on = [
    aws_lb_target_group.airflow_tg
  ]
}

