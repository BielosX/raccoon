terraform {
  required_version = ">=1.10.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.16.0"
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

data "terraform_remote_state" "frontend" {
  backend = "local"
  config = {
    path = "${path.module}/../frontend/infra/terraform.tfstate"
  }
}

locals {
  vpc_id                      = data.terraform_remote_state.cluster.outputs.vpc_id
  private_subnet_ids          = data.terraform_remote_state.cluster.outputs.private_subnet_ids
  vpc_cidr                    = data.terraform_remote_state.cluster.outputs.vpc_cidr
  bucket_name                 = data.terraform_remote_state.frontend.outputs.bucket_name
  bucket_arn                  = data.terraform_remote_state.frontend.outputs.bucket_arn
  bucket_regional_domain_name = data.terraform_remote_state.frontend.outputs.bucket_regional_domain_name
}