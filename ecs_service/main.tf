terraform {
  required_version = ">=1.10.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.13.0"
    }
  }
}

resource "aws_cloudwatch_log_group" "group" {
  name = "/${var.cluster_name}/${var.name}"
}

data "aws_iam_policy_document" "execution_role" {
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
  count              = var.create_execution_role ? 1 : 0
  assume_role_policy = data.aws_iam_policy_document.execution_role.json
}

resource "aws_iam_role_policy_attachment" "attachment" {
  count      = var.create_execution_role ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = one(aws_iam_role.execution_role).id
}

/*
  Execution Role -> Pull Images, send logs using 'awslogs' driver
  Task Role -> API calls from Task (S3, DynamoDB etc.)
 */
resource "aws_ecs_task_definition" "task_definition" {
  execution_role_arn = var.create_execution_role ? one(aws_iam_role.execution_role).id : var.execution_role_arn
  cpu                = var.cpu
  memory             = var.memory
  task_role_arn      = var.task_role_arn
  container_definitions = jsonencode([for d in var.container_definitions : {
    name       = d.name
    essential  = d.essential
    image      = d.image
    privileged = d.privileged
    user       = d.user
    command    = d.command
    linuxParameters = d.linux_parameters == null ? null : {
      initProcessEnabled = d.linux_parameters.init_process_enabled
    }
    secrets = [for s in d.secrets : {
      name      = s.name
      valueFrom = s.value_from
    }]
    dependsOn = [for e in d.depends_on : {
      condtion      = e.condition
      containerName = e.container_name
    }]
    environment = [for k, v in d.environment : {
      name  = tostring(k)
      value = tostring(v)
    }]
    portMappings = [for p in d.port_mappings : {
      containerPort = p.container_port
      name          = p.name
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-region        = var.region
        awslogs-group         = aws_cloudwatch_log_group.group.id
        awslogs-stream-prefix = "/${var.name}"
      }
    }
  }])
  family                   = var.name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }
}

resource "aws_ecs_service" "service" {
  name                              = var.name
  cluster                           = var.cluster_name
  task_definition                   = aws_ecs_task_definition.task_definition.id
  desired_count                     = var.desired_count
  enable_execute_command            = var.enable_exec_command
  health_check_grace_period_seconds = var.health_check_grace_period_seconds
  network_configuration {
    subnets         = var.subnets
    security_groups = var.security_groups
  }
  dynamic "service_connect_configuration" {
    for_each = var.service_connect == null ? [] : [1]
    content {
      enabled   = true
      namespace = var.service_connect.namespace
      dynamic "service" {
        for_each = var.service_connect.services
        content {
          port_name      = service.value.port_name
          discovery_name = service.value.discovery_name
          client_alias {
            port = service.value.port
          }
        }
      }
    }
  }
  dynamic "load_balancer" {
    for_each = var.target_groups
    content {
      container_name   = load_balancer.value.container_name
      container_port   = load_balancer.value.container_port
      target_group_arn = load_balancer.value.target_group_arn
    }
  }
  lifecycle {
    ignore_changes = [capacity_provider_strategy]
  }
}