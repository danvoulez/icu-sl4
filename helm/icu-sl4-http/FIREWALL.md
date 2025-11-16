# Firewall Configuration Guide

This guide explains how to configure network policies (firewall rules) for the ICU SL4 HTTP service.

## NetworkPolicy (Kubernetes Firewall)

Kubernetes NetworkPolicy provides pod-level network isolation. It acts as a firewall to control traffic to and from pods.

### Enable NetworkPolicy

```bash
helm install icu-sl4-http ./helm/icu-sl4-http \
  --set networkPolicy.enabled=true
```

### Common Scenarios

#### 1. Allow Only from Ingress Controller

```bash
helm install icu-sl4-http ./helm/icu-sl4-http \
  --set networkPolicy.enabled=true \
  --set networkPolicy.ingress.allowIngressController=true \
  --set networkPolicy.ingress.allowAll=false
```

#### 2. Allow from Specific Namespaces

```bash
helm install icu-sl4-http ./helm/icu-sl4-http \
  --set networkPolicy.enabled=true \
  --set networkPolicy.ingress.allowNamespaces[0]=monitoring \
  --set networkPolicy.ingress.allowNamespaces[1]=frontend
```

#### 3. Allow from Specific Pod Labels

```bash
helm install icu-sl4-http ./helm/icu-sl4-http \
  --set networkPolicy.enabled=true \
  --set networkPolicy.ingress.allowLabels.app=api-gateway \
  --set networkPolicy.ingress.allowLabels.role=frontend
```

#### 4. Allow from Specific IP Ranges (CIDR)

```bash
helm install icu-sl4-http ./helm/icu-sl4-http \
  --set networkPolicy.enabled=true \
  --set networkPolicy.ingress.allowCIDR[0]=10.0.0.0/8 \
  --set networkPolicy.ingress.allowCIDR[1]=192.168.1.0/24
```

#### 5. Restrictive: Only Same Namespace

```bash
helm install icu-sl4-http ./helm/icu-sl4-http \
  --set networkPolicy.enabled=true \
  --set networkPolicy.ingress.allowAll=false \
  --set networkPolicy.ingress.allowIngressController=false
```

#### 6. Enable Egress Control

```bash
helm install icu-sl4-http ./helm/icu-sl4-http \
  --set networkPolicy.enabled=true \
  --set networkPolicy.egress.enabled=true \
  --set networkPolicy.egress.allowCIDR[0]=10.0.0.0/8
```

### Complete Example: Production Setup

```yaml
# values-production.yaml
networkPolicy:
  enabled: true
  ingress:
    allowAll: false
    allowNamespaces:
      - ingress-nginx
      - monitoring
    allowLabels:
      app: api-gateway
      role: frontend
    allowCIDR:
      - 10.0.0.0/8  # Internal network
    allowIngressController: true
  egress:
    enabled: true
    allowAll: false
    allowCIDR:
      - 10.0.0.0/8  # Internal services
      - 0.0.0.0/0   # Internet (for TSA, etc.)
```

Install:
```bash
helm install icu-sl4-http ./helm/icu-sl4-http -f values-production.yaml
```

## Port Configuration

The service listens on:
- **Container Port**: 8787 (HTTP API)
- **Service Port**: 80 (configurable via `service.port`)

## Firewall Rules Summary

### Ingress (Incoming Traffic)

| Source | Port | Purpose |
|--------|------|---------|
| Ingress Controller | 8787 | External HTTP requests |
| Same Namespace | 8787 | Internal service calls |
| Monitoring | 8787 | Health checks, metrics |
| API Gateway | 8787 | Frontend requests |

### Egress (Outgoing Traffic)

| Destination | Port | Purpose |
|-------------|------|---------|
| DNS (kube-system) | 53/UDP | DNS resolution |
| Internal Services | Various | Service discovery |
| TSA Service | 443/TCP | Temporal anchoring (if enabled) |

## Testing NetworkPolicy

### Verify Policy Applied

```bash
kubectl get networkpolicy -n <namespace>
kubectl describe networkpolicy icu-sl4-http -n <namespace>
```

### Test Connectivity

```bash
# From allowed namespace
kubectl run -it --rm test-pod --image=curlimages/curl --restart=Never -- \
  curl http://icu-sl4-http:80/healthz

# From blocked namespace (should fail)
kubectl run -it --rm test-pod -n blocked-ns --image=curlimages/curl --restart=Never -- \
  curl http://icu-sl4-http.default:80/healthz
```

## Troubleshooting

### Service Not Accessible

1. Check NetworkPolicy is applied:
   ```bash
   kubectl get networkpolicy
   ```

2. Verify pod labels match selector:
   ```bash
   kubectl get pods -l app.kubernetes.io/name=icu-sl4-http --show-labels
   ```

3. Check if CNI plugin supports NetworkPolicy:
   ```bash
   kubectl get networkpolicies
   # If empty, CNI may not support NetworkPolicy
   ```

### Common Issues

- **CNI Plugin**: NetworkPolicy requires a CNI that supports it (Calico, Cilium, Weave, etc.)
- **Namespace Labels**: Ensure namespaces have proper labels for namespaceSelector
- **Pod Labels**: Verify pod labels match NetworkPolicy selectors

## Security Best Practices

1. **Least Privilege**: Only allow necessary sources
2. **Default Deny**: Set `allowAll: false` in production
3. **Monitor**: Use network monitoring tools to audit traffic
4. **Regular Review**: Periodically review and update policies
5. **Documentation**: Document all allowed sources and reasons

## Additional Resources

- [Kubernetes NetworkPolicy Documentation](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [CNI Plugin Comparison](https://kubernetes.io/docs/concepts/cluster-administration/networking/)

