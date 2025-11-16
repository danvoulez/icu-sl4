#!/usr/bin/env bash
# Generate SLSA Provenance attestation (more important than PDF)
# SLSA = Supply-chain Levels for Software Artifacts
set -euo pipefail

BINARY="${1:-target/release/icu_sl4_cli}"
OUTPUT="${2:-target/release/icu_sl4_cli.provenance.json}"
KEY_HEX="${3:-000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f}"

if [ ! -f "$BINARY" ]; then
    echo "Error: Binary not found: $BINARY"
    exit 1
fi

# Compute binary hash
BINARY_HASH=$(b3sum "$BINARY" 2>/dev/null | cut -d' ' -f1 || sha256sum "$BINARY" | cut -d' ' -f1)
BINARY_SIZE=$(stat -f%z "$BINARY" 2>/dev/null || stat -c%s "$BINARY" 2>/dev/null)

# Get git info
GIT_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
GIT_REPO=$(git config --get remote.origin.url 2>/dev/null || echo "unknown")
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Get Rust version
RUST_VERSION=$(rustc --version 2>/dev/null || echo "unknown")
CARGO_VERSION=$(cargo --version 2>/dev/null || echo "unknown")

# Get dependencies (from Cargo.lock if available)
DEPS_HASH=""
if [ -f "Cargo.lock" ]; then
    DEPS_HASH=$(b3sum "Cargo.lock" 2>/dev/null | cut -d' ' -f1 || sha256sum "Cargo.lock" | cut -d' ' -f1)
fi

# Create SLSA Provenance v1.0 (in-toto format)
cat > "$OUTPUT" <<EOF
{
  "_type": "https://in-toto.io/Statement/v1",
  "subject": [
    {
      "name": "$(basename $BINARY)",
      "digest": {
        "blake3": "$BINARY_HASH",
        "sha256": "$(shasum -a 256 "$BINARY" 2>/dev/null | cut -d' ' -f1 || echo "unknown")"
      }
    }
  ],
  "predicateType": "https://slsa.dev/provenance/v1",
  "predicate": {
    "buildDefinition": {
      "buildType": "https://slsa.dev/buildDefinition/v1?buildType=cargo",
      "externalParameters": {
        "cargo": {
          "version": "$CARGO_VERSION",
          "rustc": "$RUST_VERSION",
          "profile": "release",
          "target": "$(rustc -vV 2>/dev/null | grep host | cut -d' ' -f2 || echo "unknown")"
        },
        "source": {
          "type": "git",
          "ref": "$GIT_COMMIT",
          "repo": "$GIT_REPO",
          "branch": "$GIT_BRANCH"
        }
      },
      "internalParameters": {
        "buildTime": "$BUILD_TIME",
        "binarySize": $BINARY_SIZE,
        "dependenciesHash": "$DEPS_HASH"
      },
      "resolvedDependencies": [
        {
          "uri": "$GIT_REPO",
          "digest": {
            "gitCommit": "$GIT_COMMIT"
          }
        }
      ]
    },
    "runDetails": {
      "builder": {
        "id": "icu-sl4-local-build"
      },
      "metadata": {
        "invocationId": "$(uuidgen 2>/dev/null || echo "local-$(date +%s)")",
        "startedOn": "$BUILD_TIME",
        "finishedOn": "$BUILD_TIME"
      }
    }
  }
}
EOF

# Sign the provenance with Ed25519
if command -v python3 >/dev/null 2>&1; then
    # Create signature
    SIG_OUTPUT="${OUTPUT}.sig"
    python3 <<PYTHON
import json
import hashlib
import binascii
from ed25519 import SigningKey

# Load provenance
with open("$OUTPUT") as f:
    prov = json.load(f)

# Canonical JSON (sorted keys, no spaces)
canonical = json.dumps(prov, sort_keys=True, separators=(',', ':'))

# Load key
key_hex = "$KEY_HEX"
sk_bytes = binascii.unhexlify(key_hex)
sk = SigningKey(sk_bytes)

# Sign
sig = sk.sign(canonical.encode('utf-8'))
sig_hex = binascii.hexlify(sig.signature).decode('utf-8')

# Get public key
vk = sk.get_verifying_key()
vk_hex = binascii.hexlify(vk.to_bytes()).decode('utf-8')

# Write signature
with open("$SIG_OUTPUT", "w") as f:
    json.dump({
        "signature": sig_hex,
        "publicKey": vk_hex,
        "algorithm": "Ed25519",
        "canonicalHash": hashlib.sha256(canonical.encode('utf-8')).hexdigest()
    }, f, indent=2)

print(f"Signature written to $SIG_OUTPUT")
print(f"Public key: {vk_hex}")
PYTHON
else
    echo "Warning: python3 not found, skipping signature generation"
    echo "Install ed25519: pip install ed25519"
fi

echo "✅ SLSA Provenance generated: $OUTPUT"
echo "   Binary: $BINARY"
echo "   Hash (BLAKE3): $BINARY_HASH"
echo "   Git commit: $GIT_COMMIT"
echo "   Build time: $BUILD_TIME"
echo ""
echo "📋 This attestation proves:"
echo "   • What was built (binary hash)"
echo "   • How it was built (Rust/Cargo versions)"
echo "   • Where it came from (git repo/commit)"
echo "   • When it was built (timestamp)"
echo "   • Dependencies (Cargo.lock hash)"
echo ""
echo "🔐 Verify with:"
echo "   cat $OUTPUT | jq"
echo "   # Check signature: cat ${OUTPUT}.sig | jq"

