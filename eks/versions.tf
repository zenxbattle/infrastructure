terraform {
  backend "s3" {
    profile = "sandbox"
    bucket  = "sandbox-liju-terraform-backend"
    key     = "state/eks/terraform.tfstate"
    region  = "ap-south-1"
  }
  required_version = "~> 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
