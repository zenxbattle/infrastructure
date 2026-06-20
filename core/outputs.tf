output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnets
}
output "public_subnet_ids" {
  value = module.vpc.public_subnets
}

output "intra_subnet_ids" {
  value = module.vpc.intra_subnets
}

output "github_actions_ecr_role_arn" {
  value = aws_iam_role.github_actions_ecr_role.arn
}
