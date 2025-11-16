.PHONY: build test fmt clippy hash clean http pdf

build:
	cargo build --release

test:
	cargo test --all

fmt:
	cargo fmt --all

clippy:
	cargo clippy --all-targets -- -D warnings

hash:
	cargo install b3sum || true
	b3sum target/release/icu_sl4_cli || true

http:
	cargo run -p icu_sl4_http --release

pdf:
	cargo run -p icu_sl4_pdf --release -- /tmp/decision.json 000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f /tmp/decision_proof.pdf

clean:
	cargo clean
