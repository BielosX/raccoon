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

data "terraform_remote_state" "ingress" {
  backend = "local"
  config = {
    path = "${path.module}/../ingress/terraform.tfstate"
  }
}

locals {
  domain = data.terraform_remote_state.ingress.outputs.domain
}