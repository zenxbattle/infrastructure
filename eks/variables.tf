variable "aws_profile" {
  default = "sandbox"
}

# pass sensitive vars at apply time (never commit tokens):
#   TF_VAR_gitops_github_token=ghp_xxx terraform apply
# or:
#   terraform apply -var="gitops_github_user=lijuuu" -var="gitops_github_token=ghp_xxx"
#
variable "gitops_github_user" {
  description = "GitHub username for ArgoCD private repo access"
  type        = string
}

variable "gitops_github_token" {
  description = "GitHub personal access token (repo scope) for ArgoCD private repo access"
  type        = string
  sensitive   = true
}
