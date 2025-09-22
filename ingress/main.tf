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
    path = "${path.module}/../cluster/terraform.tfstate"
  }
}

locals {
  vpc_id             = data.terraform_remote_state.cluster.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.cluster.outputs.private_subnet_ids
  vpc_cidr           = data.terraform_remote_state.cluster.outputs.vpc_cidr
}