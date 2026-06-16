provider "aws" {
  region  = "ap-south-1"
  profile = var.aws_profile
}

terraform {
  required_version = ">= 1.5"
  backend "s3" {
    profile      = "sandbox"
    bucket       = "sandbox-liju-terraform-backend"
    key          = "state/core/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.79"
    }
  }
}