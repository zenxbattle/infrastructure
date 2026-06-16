resource "aws_route53_zone" "sandbox_liju_internal" {
  name = "sandbox-liju.internal"

  vpc {
    vpc_id = module.vpc.vpc_id
  }
}