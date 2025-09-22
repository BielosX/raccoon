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
    protocol    = -1
    from_port   = 0
    to_port     = 0
  }
}

resource "aws_lb" "alb" {
  name               = "raccoon-alb"
  load_balancer_type = "application"
  subnets            = local.private_subnet_ids
  security_groups    = [aws_security_group.alb_sg.id]
  internal           = true
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  protocol          = "HTTP"
  port              = 80
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "application/json"
      status_code  = "404"
      message_body = "{\"error\": \"Not Found\"}"
    }
  }
}