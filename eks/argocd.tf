resource "helm_release" "argocd" {
  depends_on = [module.eks]

  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "8.0.17"

  values = [
    <<-EOMANIFEST
      global:
        nodeSelector:
          argoproj.github.io/controller: 'true'
        tolerations:
          - key: "core-controllers"
            operator: Exists
      configs:
        params:
          server.insecure: true
        cm:
          timeout.reconciliation: "60s"
      notifications:
        enabled: false
    EOMANIFEST
  ]
}
