terraform {
  required_version = ">=1.10.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.13.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "terraform_remote_state" "cluster" {
  backend = "local"
  config = {
    path = "${path.module}/../../cluster/terraform.tfstate"
  }
}

data "terraform_remote_state" "ingress" {
  backend = "local"
  config = {
    path = "${path.module}/../../ingress/terraform.tfstate"
  }
}

data "terraform_remote_state" "cognito" {
  backend = "local"
  config = {
    path = "${path.module}/../../cognito/terraform.tfstate"
  }
}

locals {
  vpc_id                = data.terraform_remote_state.cluster.outputs.vpc_id
  private_subnet_ids    = data.terraform_remote_state.cluster.outputs.private_subnet_ids
  vpc_cidr              = data.terraform_remote_state.cluster.outputs.vpc_cidr
  listener_arn          = data.terraform_remote_state.ingress.outputs.listener_arn
  default_namespace_arn = data.terraform_remote_state.cluster.outputs.default_namespace_arn
  discovery_endpoints   = data.terraform_remote_state.cognito.outputs.discovery_endpoints
}