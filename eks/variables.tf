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

# generates with: htpasswd -nbBC 10 "" "${password}" | tr -d ':\n' | sed 's/$2y/$2a/'
# ref: https://argo-cd.readthedocs.io/en/stable/faq/#how-do-i-set-the-admin-password
variable "argocd_admin_password_hash" {
  description = "bcrypt hash of the argoCD admin password"
  type        = string
  sensitive   = true
}
