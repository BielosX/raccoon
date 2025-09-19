resource "aws_security_group" "alb_sg" {
  vpc_id = local.vpc_id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
  }
  egress {
    cidr_blocks = [local.vpc_cidr]
    protocol    = "tcp"
    from_port   = local.container_port
    to_port     = local.container_port
  }
}

resource "aws_lb" "alb" {
  name               = "raccoon-alb"
  load_balancer_type = "application"
  subnets            = local.private_subnet_ids
  security_groups    = [aws_security_group.alb_sg.id]
  internal           = true
}

resource "aws_lb_target_group" "group" {
  depends_on  = [aws_lb.alb]
  target_type = "ip"
  protocol    = "HTTP"
  port        = local.container_port
  vpc_id      = local.vpc_id
  health_check {
    enabled             = true
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 2
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  protocol          = "HTTP"
  port              = 80
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.group.arn
  }
}