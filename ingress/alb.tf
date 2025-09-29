locals {
  listener_port = 80
}

data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group" "alb_sg" {
  vpc_id = local.vpc_id
  ingress {
    prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront.id]
    protocol        = "tcp"
    from_port       = local.listener_port
    to_port         = local.listener_port
  }
  ingress {
    cidr_blocks = [local.vpc_cidr]
    protocol    = "tcp"
    from_port   = local.listener_port
    to_port     = local.listener_port
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
  port              = local.listener_port
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "application/json"
      status_code  = "404"
      message_body = "{\"error\": \"Not Found\"}"
    }
  }
}

resource "aws_cloudfront_vpc_origin" "alb_origin" {
  depends_on = [aws_security_group.alb_sg]
  vpc_origin_endpoint_config {
    arn                    = aws_lb.alb.arn
    http_port              = local.listener_port
    https_port             = 443
    name                   = "raccoon-alb-origin"
    origin_protocol_policy = "http-only"
    origin_ssl_protocols {
      items    = ["TLSv1.2"]
      quantity = 1
    }
  }
}