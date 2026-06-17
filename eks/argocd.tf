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

resource "kubernetes_manifest" "argocd_appproject" {
  depends_on = [helm_release.argocd]

  manifest = yamldecode(<<-EOMANIFEST
    apiVersion: argoproj.io/v1alpha1
    kind: AppProject
    metadata:
      name: sandbox-liju
      namespace: argocd
    spec:
      description: "sandbox-liju kubernetes cluster"
      clusterResourceWhitelist:
        - group: "*"
          kind: "*"
      destinations:
        - namespace: "*"
          server: "https://kubernetes.default.svc"
      namespaceResourceWhitelist:
        - group: "*"
          kind: "*"
      sourceRepos:
        - "*"
    EOMANIFEST
  )
}


resource "kubernetes_secret" "argocd_repo" {
  depends_on = [helm_release.argocd]

  metadata {
    name      = "sandbox-gitops"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    url      = base64encode("https://github.com/zenxbattle/sandbox-gitops")
    username = base64encode(var.gitops_github_user)
    password = base64encode(var.gitops_github_token)
  }
}

resource "kubernetes_manifest" "argocd_metaapp" {
  depends_on = [helm_release.argocd, kubernetes_manifest.argocd_appproject]

  manifest = yamldecode(<<-EOMANIFEST
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: metaapp
      namespace: argocd
      finalizers:
        - resources-finalizer.argocd.argoproj.io
    spec:
      project: sandbox-liju
      destination:
        namespace: argocd
        name: in-cluster
      source:
        repoURL: "https://github.com/zenxbattle/sandbox-gitops"
        targetRevision: HEAD
        path: charts/metaapp
        helm:
          valueFiles:
            - "../../../environments/sandbox/metaapp/values.yaml"
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - "Validate=true"
          - "CreateNamespace=true"
          - "PrunePropagationPolicy=foreground"
          - "PruneLast=true"
          - "ServerSideApply=true"
    EOMANIFEST
  )
}
