locals {
  vpc_name = "sandbox-liju"

  default_tags = {
    Terraform   = "true"
    Environment = "sandbox"
    Team        = "SRE"
  }
}
