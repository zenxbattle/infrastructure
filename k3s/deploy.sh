7337
#!/bin/bash
# Deploy XCODE on k3s — zero AWS, all on-prem
set -e

echo "=== XCODE k3s Deploy ==="
echo ""

# 1. Pre-pull worker image on all nodes
echo "[1/4] Pulling worker image..."
docker pull lijuthomas/worker:latest 2>/dev/null || echo "  skip (will pull at runtime)"

# 2. Apply all manifests
echo "[2/4] Applying k3s manifests..."
kubectl apply -k /home/zenx/zenxbattle/infrastructure/k3s/

# 3. Wait for pods
echo "[3/4] Waiting for pods..."
kubectl wait --for=condition=Ready pods --all -n xcode --timeout=120s 2>/dev/null || true

# 4. Status
echo "[4/4] Pods:"
kubectl get pods -n xcode
echo ""
echo "Services:"
kubectl get svc -n xcode
echo ""
echo "=== Done ==="
echo "Add to /etc/hosts: 192.168.10.129 xcode.local"
echo "Open: http://xcode.local"
