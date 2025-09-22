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
  assume_role_policy = data.aws_iam_policy_document.execution_role.json
}

resource "aws_iam_role_policy_attachment" "attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.execution_role.id
}

/*
  Execution Role -> Pull Images, send logs using 'awslogs' driver
  Task Role -> API calls from Task (S3, DynamoDB etc.)
 */
resource "aws_ecs_task_definition" "task_definition" {
  execution_role_arn = aws_iam_role.execution_role.arn
  cpu                = var.cpu
  memory             = var.memory
  container_definitions = jsonencode([for d in var.container_definitions : {
    name       = d.name
    essential  = d.essential
    image      = d.image
    privileged = d.privileged
    user       = d.user
    environment = [for k, v in d.environment : {
      name  = tostring(k)
      value = tostring(v)
    }]
    portMappings = [
      {
        containerPort = d.container_port
      }
    ]
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
  name            = var.name
  cluster         = var.cluster_name
  task_definition = aws_ecs_task_definition.task_definition.id
  desired_count   = var.desired_count
  network_configuration {
    subnets         = var.subnets
    security_groups = var.security_groups
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