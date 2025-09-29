resource "aws_ecs_cluster" "cluster" {
  name = var.cluster_name
}

resource "aws_ecs_cluster_capacity_providers" "providers" {
  cluster_name = aws_ecs_cluster.cluster.name

  capacity_providers = ["FARGATE_SPOT", "FARGATE"]
  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    base              = 0
    weight            = 1
  }
  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    base              = 0
    weight            = 1
  }
}

resource "aws_service_discovery_http_namespace" "default" {
  name = "default"
}