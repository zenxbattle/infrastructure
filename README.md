# ZenXBattle Infrastructure

Infrastructure-as-code for the ZenXBattle platform. Terraform for cloud resources, K3s manifests for on-prem deployment, ArgoCD for GitOps.

## Structure

```
infrastructure/
├── bootstrap/         # Terraform: initial cloud setup
│   ├── main.tf        # S3 backend, state locking
│   └── variables.tf
├── core/              # Terraform: core cloud resources
│   ├── vpc.tf         # VPC, subnets, NAT
│   ├── ecr.tf         # Docker registry
│   ├── hosted_zone.tf # DNS (Route53)
│   └── outputs.tf
├── k3s/               # On-prem Kubernetes deployment
│   ├── services/      # Per-service kustomize overlays
│   ├── monitoring/    # Prometheus + Grafana
│   ├── argocd/        # GitOps configuration
│   ├── namespace.yaml
│   ├── ingress.yaml
│   ├── kustomization.yaml
│   └── deploy.sh      # One-command deploy
├── eks/               # AWS EKS (future)
└── plans/             # Architecture decisions
```

## K3s Deployment

Deploy everything on a K3s cluster:

```bash
kubectl apply -k https://github.com/zenxbattle/infrastructure/tree/k3s/k3s
```

### Services Deployed

| Service | Type | Replicas |
|---------|------|----------|
| ApiGateway | Deployment | 2 |
| AuthUserAdminService | Deployment | 2 |
| ProblemService | Deployment | 2 |
| ChallengeService | Deployment | 2 |
| CodeExecutionEngine | Deployment | 3 |
| Frontend | Deployment | 2 |
| MongoDB | StatefulSet | 1 |
| PostgreSQL | StatefulSet | 1 |
| Redis | StatefulSet | 1 |
| NATS | StatefulSet | 1 |
| Prometheus | Deployment | 1 |
| Grafana | Deployment | 1 |

### Namespace

All services run in the `zenxbattle` namespace:

```bash
kubectl get pods -n zenxbattle
```

### Ingress

```yaml
# ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: zenxbattle
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
  - hosts: [api.zenxbattle.com, zenxbattle.com]
  rules:
  - host: api.zenxbattle.com
    http:
      paths:
      - path: /    backend: api-gateway:8080
  - host: zenxbattle.com
    http:
      paths:
      - path: /    backend: frontend:80
```

## ArgoCD (GitOps)

```bash
# Install ArgoCD
kubectl apply -k k3s/argocd

# Access
kubectl port-forward svc/argocd-server -n argocd 8080:443
# → https://localhost:8080 (admin/w70YSzuTjczGGEzFTnyNJZZcT67OC1hDCiIsm2v8719a531)
```

The ArgoCD `Application` watches this repo's `k3s/` directory and auto-syncs.

## Ansible (Alternative)

```
k3s/ansible/playbook.yml    # Declarative Ansible deployment
```

## Related Repos

All services connected:
- [ApiGateway](https://github.com/zenxbattle/ApiGateway)
- [AuthUserAdminService](https://github.com/zenxbattle/AuthUserAdminService)
- [ChallengeService](https://github.com/zenxbattle/ChallengeService)
- [CodeExecutionEngine](https://github.com/zenxbattle/CodeExecutionEngine)
- [CommonProto](https://github.com/zenxbattle/CommonProto)
- [Frontend](https://github.com/zenxbattle/Frontend)
- [MonitoringService](https://github.com/zenxbattle/MonitoringService)
- [ProblemService](https://github.com/zenxbattle/ProblemService)
- [RedisBoard](https://github.com/zenxbattle/RedisBoard)
