# XCODE on k3s — On-Premises Deployment

Zero AWS dependencies. Everything runs on k3s locally.

## Architecture

```
xcode.local
  ├─ /           → Frontend (nginx + React SPA)
  ├─ /api/*      → API Gateway (Go/Gin, port 7000)
  ├─ /ws/*       → Challenge Manager WebSocket (port 7777)
  ├─ /metrics    → Prometheus (port 9090)
  └─ /grafana    → Grafana (port 3000)

Internal services (not exposed):
  ├─ auth-user-service:50051   (gRPC — user/auth)
  ├─ problems-service:50055    (gRPC — problems)
  ├─ challenge-manager:50057   (gRPC — challenges)
  ├─ code-engine               (NATS — code execution)
  ├─ nats:4222                 (messaging)
  ├─ postgres:5432             (user data)
  ├─ mongo:27017               (problems/challenges data)
  └─ redis:6379                (cache + leaderboards)
```

## Quick Start

```bash
# 1. Pre-pull worker image (needed for code execution)
docker pull lijuthomas/worker:latest

# 2. Deploy
kubectl apply -k ./k3s/

# 3. Wait for pods
kubectl wait --for=condition=Ready pods --all -n xcode --timeout=300s

# 4. Add to /etc/hosts
echo "192.168.10.129 xcode.local" | sudo tee -a /etc/hosts

# 5. Open
open http://xcode.local   # or browse to it
```

## DockerHub Registry

All images are pulled from `lijuthomas/*` on DockerHub:
- `lijuthomas/api-gateway:latest`
- `lijuthomas/auth-user-service:latest`
- `lijuthomas/problems-service:latest`
- `lijuthomas/challenge-manager:latest`
- `lijuthomas/code-engine:latest`
- `lijuthomas/zenx2-frontend:latest`
- `lijuthomas/worker:latest` (pre-pull on node)

## Ports

| Port | Service | Protocol | Exposed |
|------|---------|----------|---------|
| 80 | Frontend | HTTP | Yes |
| 7000 | API Gateway | HTTP | Yes (via /api) |
| 7777 | Challenge WS | WebSocket | Yes (via /ws) |
| 9090 | Prometheus | HTTP | Yes (via /metrics) |
| 3000 | Grafana | HTTP | Yes (via /grafana) |
| 50051 | Auth gRPC | gRPC | No |
| 50055 | Problems gRPC | gRPC | No |
| 50057 | Challenge gRPC | gRPC | No |
| 4222 | NATS | TCP | No |
| 5432 | PostgreSQL | TCP | No |
| 27017 | MongoDB | TCP | No |
| 6379 | Redis | TCP | No |
