locals {
  service_name        = "keycloak"
  container_port_name = "http"
  container_port      = 8080
  main_container      = "main"
  management_port     = 9000
  path_prefix         = "/app/auth"
}

resource "aws_lb_target_group" "group" {
  target_type = "ip"
  protocol    = "HTTP"
  port        = local.container_port
  vpc_id      = local.vpc_id
  health_check {
    enabled             = true
    path                = "/health/ready"
    port                = local.management_port
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 2
  }
  tags = {
    Service = local.service_name
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
  ingress {
    cidr_blocks = [local.vpc_cidr]
    protocol    = "tcp"
    from_port   = local.management_port
    to_port     = local.management_port
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
  }
}

resource "aws_lb_listener_rule" "rule" {
  listener_arn = local.listener_arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.group.arn
  }

  condition {
    path_pattern {
      values = ["${local.path_prefix}/*"]
    }
  }
}

resource "random_password" "password" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "secret" {
  name = "/${var.cluster_name}/keycloak/admin-password"
}

resource "aws_secretsmanager_secret_version" "password" {
  secret_id     = aws_secretsmanager_secret.secret.id
  secret_string = random_password.password.result
}

data "aws_iam_policy_document" "ecs_task_trust_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["ecs-tasks.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "execution_role" {
  assume_role_policy = data.aws_iam_policy_document.ecs_task_trust_policy.json
}

resource "aws_iam_role_policy_attachment" "attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.execution_role.id
}

data "aws_iam_policy_document" "execution_role_policy" {
  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.secret.arn]
  }
}

resource "aws_iam_role_policy" "execution_role_policy" {
  policy = data.aws_iam_policy_document.execution_role_policy.json
  role   = aws_iam_role.execution_role.id
}

resource "aws_iam_role" "task_role" {
  assume_role_policy = data.aws_iam_policy_document.ecs_task_trust_policy.json
}

data "aws_iam_policy_document" "task_role_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "task_role_policy" {
  policy = data.aws_iam_policy_document.task_role_policy.json
  role   = aws_iam_role.task_role.id
}

module "service" {
  source                            = "../../ecs_service"
  name                              = local.service_name
  cluster_name                      = var.cluster_name
  create_execution_role             = false
  execution_role_arn                = aws_iam_role.execution_role.arn
  task_role_arn                     = aws_iam_role.task_role.arn
  desired_count                     = 1
  cpu                               = 1024
  memory                            = 2048
  health_check_grace_period_seconds = 60
  region                            = var.region
  enable_exec_command               = true
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
    command    = ["start-dev"]
    linux_parameters = {
      init_process_enabled = true
    }
    environment = {
      KC_BOOTSTRAP_ADMIN_USERNAME = "admin"
      KC_HEALTH_ENABLED           = "true"
      KC_HTTP_MANAGEMENT_PORT     = local.management_port
      KC_HTTP_RELATIVE_PATH       = local.path_prefix
    }
    secrets = [{
      name       = "KC_BOOTSTRAP_ADMIN_PASSWORD"
      value_from = aws_secretsmanager_secret.secret.arn
    }]
    port_mappings = [
      {
        container_port = local.container_port
        name           = local.container_port_name
      },
      {
        container_port = local.management_port
      }
    ]
  }]
  target_groups = [{
    container_name   = local.main_container
    container_port   = local.container_port
    target_group_arn = aws_lb_target_group.group.arn
  }]
  security_groups = [aws_security_group.service_sg.id]
  subnets         = local.private_subnet_ids
}