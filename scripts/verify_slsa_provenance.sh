#!/usr/bin/env bash
# Verify SLSA Provenance attestation
set -euo pipefail

PROVENANCE="${1:-target/release/icu_sl4_cli.provenance.json}"
SIGNATURE="${2:-target/release/icu_sl4_cli.provenance.json.sig}"
BINARY="${3:-target/release/icu_sl4_cli}"

if [ ! -f "$PROVENANCE" ]; then
    echo "Error: Provenance file not found: $PROVENANCE"
    exit 1
fi

echo "=== Verifying SLSA Provenance ==="
echo ""

# Verify binary hash matches
if [ -f "$BINARY" ]; then
    BINARY_HASH=$(b3sum "$BINARY" 2>/dev/null | cut -d' ' -f1 || sha256sum "$BINARY" | cut -d' ' -f1)
    PROV_HASH=$(cat "$PROVENANCE" | python3 -c "import sys, json; print(json.load(sys.stdin)['subject'][0]['digest'].get('blake3', 'unknown'))" 2>/dev/null || echo "unknown")
    
    if [ "$BINARY_HASH" = "$PROV_HASH" ]; then
        echo "✅ Binary hash matches: $BINARY_HASH"
    else
        echo "❌ Binary hash mismatch!"
        echo "   Binary: $BINARY_HASH"
        echo "   Provenance: $PROV_HASH"
        exit 1
    fi
fi

# Verify signature if available
if [ -f "$SIGNATURE" ]; then
    if command -v python3 >/dev/null 2>&1; then
        python3 <<PYTHON
import json
import binascii
import hashlib
from ed25519 import VerifyingKey

# Load provenance
with open("$PROVENANCE") as f:
    prov = json.load(f)

# Canonical JSON
canonical = json.dumps(prov, sort_keys=True, separators=(',', ':'))

# Load signature
with open("$SIGNATURE") as f:
    sig_data = json.load(f)

sig_hex = sig_data["signature"]
vk_hex = sig_data["publicKey"]
expected_hash = sig_data.get("canonicalHash", "")

# Verify hash
actual_hash = hashlib.sha256(canonical.encode('utf-8')).hexdigest()
if expected_hash and actual_hash != expected_hash:
    print(f"❌ Hash mismatch!")
    print(f"   Expected: {expected_hash}")
    print(f"   Actual: {actual_hash}")
    exit(1)

# Verify signature
vk_bytes = binascii.unhexlify(vk_hex)
sig_bytes = binascii.unhexlify(sig_hex)
vk = VerifyingKey(vk_bytes)

try:
    vk.verify(sig_bytes, canonical.encode('utf-8'))
    print("✅ Signature valid")
    print(f"   Public key: {vk_hex[:16]}...{vk_hex[-16:]}")
except:
    print("❌ Signature verification failed!")
    exit(1)
PYTHON
    else
        echo "⚠️  python3 not found, skipping signature verification"
    fi
else
    echo "⚠️  Signature file not found: $SIGNATURE"
fi

echo ""
echo "✅ Provenance verification complete!"

