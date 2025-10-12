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

module "bucket" {
  source      = "./../../private_bucket"
  name_prefix = "raccoon-frontend-"
}