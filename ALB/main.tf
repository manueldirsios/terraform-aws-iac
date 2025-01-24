provider "aws" {
  region = "us-west-1" # Cambia a tu región preferida
}

# 1. Crear el Target Group
resource "aws_lb_target_group" "ecs_tg" {
  name        = "TG-ALB-MICROSERVICE-TFM"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = "vpc-09a1df448b7c1a839" # Cambia por tu VPC
  target_type = "ip"
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }
}

# 2. Crear el Load Balancer (ALB)
resource "aws_lb" "ecs_alb" {
  name               = "ALB-TFM"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.SG-ALB-TFM.id]
  subnets            = ["subnet-0e2ccef71ac17fea2","subnet-0bb2e1d426f7f0dc7"]
}

# 3. Crear el Listener del ALB
resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.ecs_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_tg.arn
  }
}

# 4. Seguridad para el Balanceador
resource "aws_security_group" "SG-ALB-TFM" {
  name        = "ALB-SG-TFM"
  description = "Permite todo el trafico"
  vpc_id      = "vpc-09a1df448b7c1a839"

  ingress {
    from_port   = 80
    to_port     = 80
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

output "alb_dns_name" {
  value = aws_lb.ecs_alb.dns_name
}
