#!/usr/bin/env bash
set -euo pipefail
rustup toolchain install 1.79.0 --profile minimal --component clippy rustfmt
rustup override set 1.79.0
cargo build --release --locked
if command -v b3sum >/dev/null 2>&1; then b3sum target/release/icu_sl4_cli; fi
