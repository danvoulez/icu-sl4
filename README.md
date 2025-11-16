# ICU SL4 — Complete Workspace

Deterministic engine + CLI + HTTP + PDF + CI + Release + Docker + K8s + Helm + OpenAPI + FHIR.

## Quickstart

```bash
# build
cargo build --release

# decide (CLI)
./target/release/icu_sl4_cli decide \
  --input examples/input.json \
  --policy examples/policy_hypoxemia.yaml \
  --keypair examples/keypair.json \
  --binary_hash blake3:engine-demo@0.1.0 \
  --config_hash blake3:prod-euwest \
  --out /tmp/decision.json

# verify (CLI)
./target/release/icu_sl4_cli verify --decision /tmp/decision.json
# ✓ Signature valid

# http server
cargo run -p icu_sl4_http --release

# Health check
curl -s localhost:8787/healthz

# OpenAPI/Swagger UI
# Visit http://localhost:8787/swagger-ui/ in your browser
```

## HTTP API

### Standard Decision Endpoint
```bash
curl -s localhost:8787/decide -H 'content-type: application/json' -d @- <<'JSON'
{
  "input": { "text": "paciente com saturação 85%, taquicárdico, sudorese",
             "measured": {"spo2_pct":85, "hr_bpm":125} },
  "policy_yaml": "---\nprotocol_id: hypoxemia_acute\nversion: 1.0.0\n...",
  "keypair_secret_hex": "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f",
  "binary_hash": "blake3:http-demo@0.1.0",
  "config_hash": "blake3:prod-euwest",
  "ledger_path": "/tmp/ledger.ndjson"
}
JSON
```

### FHIR Observation Endpoint
```bash
curl -s localhost:8787/fhir/observation -H 'content-type: application/json' -d @- <<'JSON'
{
  "observation": {
    "resource_type": "Observation",
    "id": "obs-123",
    "status": "final",
    "code": {
      "coding": [{
        "system": "http://loinc.org",
        "code": "2708-6",
        "display": "Oxygen saturation in Arterial blood"
      }],
      "text": "SpO2"
    },
    "value_quantity": {
      "value": 85,
      "unit": "%",
      "code": "%"
    },
    "note": [{
      "text": "paciente com saturação 85%, taquicárdico"
    }]
  },
  "policy_yaml": "---\nprotocol_id: hypoxemia_acute\n...",
  "keypair_secret_hex": "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
}
JSON
```

### OpenAPI Documentation
- **Swagger UI**: http://localhost:8787/swagger-ui/
- **OpenAPI JSON**: http://localhost:8787/api-doc/openapi.json

## PDF Proof
```bash
cargo run -p icu_sl4_pdf --release -- \
  /tmp/decision.json \
  000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f \
  /tmp/decision_proof.pdf
```

## Docker
```bash
docker build -f docker/Dockerfile.http -t icu-sl4-http:local .
docker run --rm -p 8787:8787 icu-sl4-http:local
```

## Kubernetes

### Direct Deployment
Apply `k8s/deployment.yaml` after pushing your image to a registry:
```bash
kubectl apply -f k8s/deployment.yaml
```

### NetworkPolicy (Firewall)
Apply network isolation rules:
```bash
kubectl apply -f k8s/networkpolicy.yaml
```

See `helm/icu-sl4-http/FIREWALL.md` for detailed firewall configuration.

### Helm Chart
```bash
# Install with default values
helm install icu-sl4-http ./helm/icu-sl4-http

# Install with custom values
helm install icu-sl4-http ./helm/icu-sl4-http \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host=icu-sl4.example.com

# With persistence for ledger
helm install icu-sl4-http ./helm/icu-sl4-http \
  --set persistence.enabled=true \
  --set persistence.size=10Gi

# With autoscaling
helm install icu-sl4-http ./helm/icu-sl4-http \
  --set autoscaling.enabled=true \
  --set autoscaling.minReplicas=2 \
  --set autoscaling.maxReplicas=10
```

See `helm/icu-sl4-http/README.md` for more details.

## CI & Release
- `ci.yaml`: fmt + clippy (strict) + build + tests + BLAKE3.
- `release.yaml`: tag `v*` → build binaries, **SBOM** (SPDX), **provenance**, release assets.

## Features

- ✅ **Deterministic Decision Engine**: Dual-channel TDLN with cryptographic proof
- ✅ **CLI Tool**: Command-line interface for decisions and verification
- ✅ **HTTP API**: RESTful API with OpenAPI documentation
- ✅ **FHIR Integration**: `/fhir/observation` endpoint for FHIR R4 Observation resources
- ✅ **PDF Proof Generation**: Signed PDF proofs with detached signatures
- ✅ **Helm Chart**: Production-ready Kubernetes deployment
- ✅ **Docker Support**: Containerized deployments
- ✅ **Reproducible Builds**: BLAKE3 hashing and deterministic JSON
