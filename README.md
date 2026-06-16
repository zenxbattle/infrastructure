# sandbox-liju

terraform + gitops on EKS. learning playground.

## progress

- [x] bootstrap — S3 backend bucket
- [x] bootstrap — migrate state to S3
- [x] core — VPC (private, public, intra subnets)
- [x] core — hosted zone `sandbox-liju.internal`
- [x] eks — EKS cluster with core-controllers node
- [ ] eks — karpenter + EC2NodeClass
- [ ] eks — argoCD + AppProject + metaapp
- [ ] eks — pod identities (aws-lbc, external-dns, cert-manager)
- [ ] gitops — mock repo + connect argoCD
- [ ] gitops — karpenter nodepool
- [ ] gitops — external-secrets
- [ ] gitops — gateway-api CRDs
- [ ] gitops — aws-lbc
- [ ] gitops — external-dns
- [ ] gitops — kong-internal
- [ ] gitops — cert-manager
- [ ] gitops — certificate-issuers
- [ ] gitops — gateway-resources
- [ ] gitops — HTTPRoute for argocd
- [ ] verify — access argoCD