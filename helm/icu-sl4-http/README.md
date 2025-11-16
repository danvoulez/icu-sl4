# ICU SL4 HTTP Helm Chart

Helm chart for deploying the ICU SL4 HTTP service to Kubernetes.

## Installation

```bash
# Install with default values
helm install icu-sl4-http ./helm/icu-sl4-http

# Install with custom values
helm install icu-sl4-http ./helm/icu-sl4-http -f my-values.yaml

# Upgrade existing release
helm upgrade icu-sl4-http ./helm/icu-sl4-http
```

## Configuration

Key configuration options in `values.yaml`:

- `image.repository`: Container image repository
- `image.tag`: Container image tag
- `replicaCount`: Number of replicas
- `service.type`: Service type (ClusterIP, NodePort, LoadBalancer)
- `ingress.enabled`: Enable ingress
- `resources`: CPU and memory limits/requests
- `autoscaling.enabled`: Enable horizontal pod autoscaling
- `persistence.enabled`: Enable persistent storage for ledger

## Examples

### Basic deployment
```bash
helm install icu-sl4-http ./helm/icu-sl4-http
```

### With ingress enabled
```bash
helm install icu-sl4-http ./helm/icu-sl4-http \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host=icu-sl4.example.com
```

### With persistence
```bash
helm install icu-sl4-http ./helm/icu-sl4-http \
  --set persistence.enabled=true \
  --set persistence.size=10Gi
```

### With autoscaling
```bash
helm install icu-sl4-http ./helm/icu-sl4-http \
  --set autoscaling.enabled=true \
  --set autoscaling.minReplicas=2 \
  --set autoscaling.maxReplicas=10
```

## NetworkPolicy (Firewall)

Configure Kubernetes NetworkPolicy for network isolation:

```bash
# Enable basic NetworkPolicy
helm install icu-sl4-http ./helm/icu-sl4-http \
  --set networkPolicy.enabled=true

# Production setup with restrictions
helm install icu-sl4-http ./helm/icu-sl4-http \
  --set networkPolicy.enabled=true \
  --set networkPolicy.ingress.allowNamespaces[0]=ingress-nginx \
  --set networkPolicy.ingress.allowCIDR[0]=10.0.0.0/8
```

See `FIREWALL.md` for detailed firewall configuration options.

## Uninstallation

```bash
helm uninstall icu-sl4-http
```

