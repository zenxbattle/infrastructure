# finds the VPC by its Name tag — core vpc.tf set name = "sandbox-liju"
data "aws_vpc" "selected" {
  filter {
    name   = "tag:Name"
    values = [local.vpc_name]
  }
}

# finds private subnets — EKS places the managed node group here
# two tags required: private=1 (marks it private) + kubernetes.io/cluster/<name>=shared (EKS ownership)
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
  tags = {
    "private"                            = "1"
    "kubernetes.io/cluster/sandbox-liju" = "shared"
  }
}

# reads the AWS account ID — used to construct the SSO access entry IAM ARN
data "aws_caller_identity" "current" {}

# IAM role created by SSO for users with AdministratorAccess
# the suffix is stable — only changes if the SSO permission set is recreated
data "aws_iam_role" "sso_administratoraccess" {
  name = "AWSReservedSSO_AdministratorAccess_1305a4c1e8802a15"
}

# hosted zone created in core/hosted_zone.tf, used by external-dns and cert-manager pod identities
data "aws_route53_zone" "sandbox_liju_internal" {
  name         = "sandbox-liju.internal"
  private_zone = true
}
