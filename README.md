# sandbox-liju

terraform + gitops on EKS. learning playground. org: `zenxbattle`.

## pools

```
core-controllers (managed, fixed 1, tainted) → karpenter, argoCD, ebs-csi, coredns
platform-apps    (karpenter, on-demand)       → kong, cert-manager, external-dns, aws-lbc, auth, api-gateway, problems, nats
engine           (karpenter, on-demand)       → code-exec workers
```

## progress

- [x] bootstrap — S3 backend bucket
- [x] bootstrap — migrate state to S3
- [x] core — VPC (private, public, intra subnets)
- [x] core — hosted zone `sandbox-liju.internal`
- [x] eks — EKS cluster + core-controllers node
- [x] eks — karpenter controller
- [x] eks — argoCD install (`helm_release.argocd`)
- [x] eks — argoCD appproject + repo secret + metaapp
- [x] eks — EC2NodeClass (in karpenter.tf)
- [x] core — ECR repos + GitHub OIDC
- [x] eks — pod identities (aws-lbc, external-dns, cert-manager)
- [ ] gitops — repo + connect argoCD
- [ ] infisical — clustersecretstore + externalsecret
- [ ] gitops — infra apps (kong, cert-manager, external-dns, aws-lbc)
- [ ] gitops — karpenter NodePools (platform-apps + engine)
- [ ] gitops — platform apps (auth, api-gateway, problems, nats)
- [ ] gitops — engine apps (code-exec)
- [ ] gitops — HTTPRoute + gateway resources
- [ ] verify — access argoCD
