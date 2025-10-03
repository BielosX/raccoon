resource "aws_security_group" "alb_sg" {
  vpc_id = local.vpc_id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
  }
  egress {
    cidr_blocks = [local.vpc_cidr]
    protocol    = -1
    from_port   = 0
    to_port     = 0
  }
}

resource "aws_lb" "alb" {
  name               = "keycloak-alb"
  internal           = true
  load_balancer_type = "application"
  subnets            = local.private_subnet_ids
  security_groups    = [aws_security_group.alb_sg.id]
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.group.arn
  }
}