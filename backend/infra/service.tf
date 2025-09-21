locals {
  main_container = "main"
  container_port = 8080
  uid            = "1001"
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

module "service" {
  depends_on    = [aws_lb.alb]
  source        = "../../ecs_service"
  name          = "raccoon"
  cluster_name  = var.cluster_name
  desired_count = 2
  cpu           = 256
  memory        = 512
  region        = var.region
  container_definitions = [{
    name           = local.main_container
    essential      = true
    image          = var.image
    privileged     = false
    user           = local.uid
    container_port = local.container_port
    environment = {
      PORT = local.container_port
    }
  }]
  load_balancers = [{
    container_name   = local.main_container
    container_port   = local.container_port
    target_group_arn = aws_lb_target_group.group.arn
  }]
  security_groups = [aws_security_group.service_sg.id]
  subnets         = local.private_subnet_ids
}