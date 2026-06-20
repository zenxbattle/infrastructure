module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "sandbox-liju"
  cidr = "10.5.0.0/16"

  azs             = ["ap-south-1a", "ap-south-1b"]
  private_subnets = ["10.5.0.0/24", "10.5.1.0/24"]
  public_subnets  = ["10.5.64.0/24", "10.5.65.0/24"]
  intra_subnets   = ["10.5.128.0/24", "10.5.129.0/24"]

  private_subnet_tags = {
    "private"                            = 1
    "kubernetes.io/role/internal-elb"    = 1
    "kubernetes.io/cluster/sandbox-liju" = "shared"
  }

  public_subnet_tags = {
    "public"                 = 1
    "kubernetes.io/role/elb" = 1
  }

  intra_subnet_tags = {
    "rds"         = 1
    "elasticache" = 1
  }

  enable_nat_gateway     = true
  one_nat_gateway_per_az = true

  tags = local.default_tags
}