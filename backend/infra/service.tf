locals {
  main_container = "main"
  container_port = 8080
  uid            = "1001"
  env_variables = {
    PORT = local.container_port
  }
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

resource "aws_cloudwatch_log_group" "group" {
  name = "/${var.cluster_name}/raccoon"
}

/*
  Execution Role -> Pull Images, send logs using 'awslogs' driver
  Task Role -> API calls from Task (S3, DynamoDB etc.)
 */
resource "aws_ecs_task_definition" "task_definition" {
  network_mode             = "awsvpc"
  family                   = "raccoon"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.execution_role.arn
  cpu                      = 256
  memory                   = 512
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }
  container_definitions = jsonencode([{
    name       = local.main_container
    essential  = true
    image      = var.image
    privileged = false,
    user       = local.uid,
    portMappings = [
      {
        containerPort = local.container_port
      }
    ]
    environment = [for k, v in local.env_variables : {
      name  = tostring(k)
      value = tostring(v)
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-region        = var.region
        awslogs-group         = aws_cloudwatch_log_group.group.id
        awslogs-stream-prefix = "/raccoon"
      }
    }
  }])
}

resource "aws_security_group" "service_sg" {
  vpc_id = local.vpc_id
  ingress {
    security_groups = [aws_security_group.alb_sg.id]
    protocol        = "tcp"
    from_port       = local.container_port
    to_port         = local.container_port
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
  }
}

resource "aws_ecs_service" "service" {
  name            = "raccoon"
  cluster         = var.cluster_name
  task_definition = aws_ecs_task_definition.task_definition.id
  desired_count   = 2
  network_configuration {
    subnets         = local.private_subnet_ids
    security_groups = [aws_security_group.service_sg.id]
  }
  load_balancer {
    container_name   = local.main_container
    container_port   = local.container_port
    target_group_arn = aws_lb_target_group.group.arn
  }
  lifecycle {
    ignore_changes = [capacity_provider_strategy]
  }
}