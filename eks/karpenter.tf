module "karpenter" {
  source = "terraform-aws-modules/eks/aws//modules/karpenter"

  cluster_name = module.eks.cluster_name

  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    AmazonEBSCSIDriverPolicy     = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  }

  # AWS IAM inline policy limit (6144 chars) exceeded without this flag
  # https://github.com/terraform-aws-modules/terraform-aws-eks/issues/3512
  enable_inline_policy = true

  tags = local.default_tags
}

resource "helm_release" "karpenter" {
  depends_on = [module.eks]

  namespace  = "kube-system"
  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = "1.6.1"

  values = [
    <<-EOT
    replicas: 1
    nodeSelector:
      karpenter.sh/controller: 'true'
    tolerations:
      - key: "core-controllers"
        operator: Exists
    dnsPolicy: Default
    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      interruptionQueue: ${module.karpenter.queue_name}
    webhook:
      enabled: false
    EOT
  ]
}

resource "kubernetes_manifest" "common_nodeclass" {
  depends_on = [helm_release.karpenter]

  manifest = yamldecode(<<-EOMANIFEST
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: liju-common
    spec:
      amiSelectorTerms:
        - alias: al2023@latest
      role: ${module.karpenter.node_iam_role_name}
      subnetSelectorTerms:
        - tags:
            private: "1"
            kubernetes.io/cluster/sandbox-liju: "shared"
      securityGroupSelectorTerms:
        - id: ${module.eks.node_security_group_id}
      associatePublicIPAddress: false
      metadataOptions:
        httpPutResponseHopLimit: 2
      tags:
        karpenter.sh/nodeclass: liju-common
    EOMANIFEST
  )
}

resource "kubernetes_manifest" "engine_nodeclass" {
  depends_on = [helm_release.karpenter]

  manifest = yamldecode(<<-EOMANIFEST
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: engine
    spec:
      amiSelectorTerms:
        - alias: al2023@latest
      role: ${module.karpenter.node_iam_role_name}
      subnetSelectorTerms:
        - tags:
            private: "1"
            kubernetes.io/cluster/sandbox-liju: "shared"
      securityGroupSelectorTerms:
        - id: ${module.eks.node_security_group_id}
      associatePublicIPAddress: false
      metadataOptions:
        httpPutResponseHopLimit: 2
      userData: |
        MIME-Version: 1.0
        Content-Type: multipart/mixed; boundary="BOUNDARY"

        --BOUNDARY
        Content-Type: text/x-shellscript; charset="us-ascii"

        #!/bin/bash
        set -ex
        dnf install -y docker
        systemctl enable docker
        systemctl start docker
        --BOUNDARY--
      tags:
        karpenter.sh/nodeclass: engine
    EOMANIFEST
  )
}
