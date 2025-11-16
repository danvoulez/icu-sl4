#!/usr/bin/env bash
set -euo pipefail
BIN=target/release/icu_sl4_cli
if [ -f "$BIN" ]; then
  if command -v b3sum >/dev/null 2>&1; then b3sum "$BIN"; else echo "Install b3sum with: cargo install b3sum"; fi
else
  echo "Binary not found at $BIN"
fi
