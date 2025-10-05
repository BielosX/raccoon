locals {
  main_container      = "main"
  container_port      = 8080
  container_port_name = "http"
  uid                 = "1001"
  service_name        = "raccoon"
  health_path         = "/health"
  path_prefix         = "/app/ws"
}

resource "aws_lb_target_group" "group" {
  target_type = "ip"
  protocol    = "HTTP"
  port        = local.container_port
  vpc_id      = local.vpc_id
  health_check {
    enabled             = true
    path                = local.health_path
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 2
  }
  tags = {
    Service = local.service_name
  }
}

resource "aws_lb_listener_rule" "rule" {
  listener_arn = local.listener_arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.group.arn
  }

  /*
    ALB does not provide path rewriter. App should expose endpoints prefixed with /app/ws
   */
  condition {
    path_pattern {
      values = ["${local.path_prefix}/*"]
    }
  }
}

resource "aws_security_group" "service_sg" {
  vpc_id = local.vpc_id
  ingress {
    cidr_blocks = [local.vpc_cidr]
    protocol    = "tcp"
    from_port   = local.container_port
    to_port     = local.container_port
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
  }
}

module "service" {
  source                = "../../ecs_service"
  name                  = local.service_name
  cluster_name          = var.cluster_name
  desired_count         = 2
  cpu                   = 256
  memory                = 512
  region                = var.region
  create_execution_role = true
  service_connect = {
    namespace = local.default_namespace_arn
    services = [{
      discovery_name = local.service_name
      port_name      = local.container_port_name
      port           = local.container_port
    }]
  }
  container_definitions = [{
    name       = local.main_container
    essential  = true
    image      = var.image
    privileged = false
    user       = local.uid
    port_mappings = [{
      container_port = local.container_port
      name           = local.container_port_name
    }]
    environment = {
      PORT           = local.container_port
      WS_PATH_PREFIX = local.path_prefix
      # noinspection HILUnresolvedReference
      OPENID_CONFIGURATION_URL = local.discovery_endpoints.openid_configuration
      # noinspection HILUnresolvedReference
      JWKS_URL = local.discovery_endpoints.jwks
    }
  }]
  target_groups = [{
    container_name   = local.main_container
    container_port   = local.container_port
    target_group_arn = aws_lb_target_group.group.arn
  }]
  security_groups = [aws_security_group.service_sg.id]
  subnets         = local.private_subnet_ids
}