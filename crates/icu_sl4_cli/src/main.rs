use anyhow::Result;
use clap::{Parser, Subcommand};
use icu_sl4_engine::*;
use serde_json::json;
use std::fs;
use std::path::PathBuf;
use time::OffsetDateTime;

#[derive(Parser)]
#[command(name = "icu-sl4")]
#[command(about = "Deterministic ICU decision engine (demo)")]
struct Cli {
    #[command(subcommand)]
    cmd: Cmd,
}

#[derive(Subcommand)]
enum Cmd {
    /// Make a deterministic decision
    Decide {
        /// Input JSON path
        #[arg(long)]
        input: PathBuf,
        /// Policy YAML path
        #[arg(long)]
        policy: PathBuf,
        /// Keypair JSON path { "secret_hex": "<64 hex>" }
        #[arg(long)]
        keypair: PathBuf,
        /// Binary hash (string to pin build)
        #[arg(long, default_value = "blake3:demo-binary")]
        binary_hash: String,
        /// Config hash (string to pin config)
        #[arg(long, default_value = "blake3:demo-config")]
        config_hash: String,
        /// Output JSON path (decision)
        #[arg(long)]
        out: PathBuf,
        /// Append to NDJSON ledger (optional)
        #[arg(long)]
        ledger: Option<PathBuf>,
    },
    /// Verify a decision file's signature & hashes
    Verify {
        /// Path to decision JSON produced by `decide`
        #[arg(long)]
        decision: PathBuf,
    },
    /// Generate a random Ed25519 keypair (JSON file with secret_hex)
    GenKey {
        #[arg(long)]
        out: PathBuf,
    },
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    match cli.cmd {
        Cmd::Decide {
            input,
            policy,
            keypair,
            binary_hash,
            config_hash,
            out,
            ledger,
        } => {
            let inp: Input = serde_json::from_str(&fs::read_to_string(&input)?)?;
            let pol: Policy = load_policy_yaml(&policy)?;
            let (sk, _vk) = keypair_from_json(&keypair)?;
            let now = OffsetDateTime::now_utc()
                .format(&time::format_description::well_known::Rfc3339)
                .unwrap();

            let d = decide(&inp, &pol, &binary_hash, &config_hash, &sk, &now)?;

            let mut decision_v = json!({
                "ast": d.ast,
                "decision": d.decision,
                "proof_pack": d.proof_pack,
                "frontier": d.frontier,
            });

            // If a ledger path is provided, append and link blockstamp
            if let Some(ledger_path) = ledger {
                let h = ledger_append(&ledger_path, &decision_v)?;
                if let Some(obj) = decision_v.as_object_mut() {
                    obj.insert(
                        "ledger_block_hash".to_string(),
                        serde_json::Value::String(h),
                    );
                }
            }

            fs::write(&out, serde_json::to_string_pretty(&decision_v)?)?;
            println!("Wrote decision to {}", out.display());
        }
        Cmd::Verify { decision } => {
            let v: serde_json::Value = serde_json::from_str(&fs::read_to_string(&decision)?)?;
            let pp = &v["proof_pack"];
            // Rebuild unsigned for verification
            let unsigned = json!({
                "input_hash": pp["input_hash"],
                "ast_hash": pp["ast_hash"],
                "policy_hash": pp["policy_hash"],
                "binary_hash": pp["binary_hash"],
                "config_hash": pp["config_hash"],
                "decision_time": pp["decision_time"],
                "tsa_token": pp["tsa_token"],
                "sign": serde_json::Value::Null,
                "link_prev": pp["link_prev"],
            });
            let canonical = json_canonical(&unsigned)?;
            let sig_hex = pp["sign"]["sig"].as_str().unwrap();
            let pub_hex = pp["sign"]["pubkey"].as_str().unwrap();
            let sig_bytes = hex::decode(sig_hex).expect("bad sig hex");
            let pk_bytes = hex::decode(pub_hex).expect("bad pub hex");
            let sig = ed25519_dalek::Signature::from_bytes(&sig_bytes.try_into().unwrap());
            let vk =
                ed25519_dalek::VerifyingKey::from_bytes(&pk_bytes.try_into().unwrap()).unwrap();
            verify_bytes(&vk, canonical.as_bytes(), &sig)?;
            println!("✓ Signature valid");
        }
        Cmd::GenKey { out } => {
            let sk = ed25519_dalek::SigningKey::generate(&mut rand::rngs::OsRng);
            let hex_secret = hex::encode(sk.to_bytes());
            let doc = serde_json::json!({ "secret_hex": hex_secret });
            fs::write(&out, serde_json::to_string_pretty(&doc)?)?;
            println!("Wrote keypair secret to {}", out.display());
        }
    }
    Ok(())
}
