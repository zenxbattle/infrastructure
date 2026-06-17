locals {
  vpc_name = "sandbox-liju"

  default_tags = {
    Terraform   = "true"
    Environment = "sandbox"
    Team        = "SRE"
  }

  eks_get_token_args = [
    "eks", "get-token",
    "--cluster-name", "sandbox-liju",
    "--profile", var.aws_profile
  ]
}
