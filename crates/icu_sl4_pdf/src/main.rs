use anyhow::Result;
use ed25519_dalek::{Signer, SigningKey};
use genpdf::Alignment;
use genpdf::{elements, style};
use icu_sl4_engine::json_canonical;
use serde_json::Value;
use std::fs;
use std::path::PathBuf;

fn main() -> Result<()> {
    let mut args = std::env::args().skip(1);
    let decision_path = PathBuf::from(
        args.next()
            .expect("usage: icu_sl4_pdf <decision.json> <keypair_secret_hex> <out.pdf>"),
    );
    let secret_hex = args.next().expect("missing keypair_secret_hex");
    let out_pdf = PathBuf::from(args.next().expect("missing out.pdf"));

    let decision_s = fs::read_to_string(&decision_path)?;
    let v: Value = serde_json::from_str(&decision_s)?;
    let canonical = json_canonical(&v)?;
    let decision_hash = format!("blake3:{}", blake3::hash(canonical.as_bytes()).to_hex());

    let sk_bytes = hex::decode(secret_hex).expect("bad secret hex");
    let sk = SigningKey::from_bytes(&sk_bytes.try_into().unwrap());
    let sig = sk.sign(canonical.as_bytes());
    let sig_hex = hex::encode(sig.to_bytes());
    let pub_hex = hex::encode(sk.verifying_key().to_bytes());

    // PDF
    let font = genpdf::fonts::FontFamily::default();
    let mut doc = genpdf::Document::new(font);
    doc.set_title("ICU SL4 Decision Proof");
    doc.set_minimal_conformance();
    doc.set_line_spacing(1.2);

    let heading = elements::Paragraph::new("ICU SL4 — Decision Proof")
        .styled(style::Style::new().bold().with_align(Alignment::Center));
    doc.push(heading);
    doc.push(elements::Break::new(1));

    doc.push(elements::Paragraph::new(format!(
        "Decision file: {}",
        decision_path.display()
    )));
    doc.push(elements::Paragraph::new(format!(
        "Decision BLAKE3: {}",
        decision_hash
    )));
    doc.push(elements::Paragraph::new(format!(
        "Public Key (Ed25519): {}",
        pub_hex
    )));
    doc.push(elements::Paragraph::new(format!(
        "Detached Signature (hex): {}",
        sig_hex
    )));
    doc.push(elements::Break::new(1));
    doc.push(elements::Paragraph::new("Verification: Verify by recomputing the canonical JSON (sorted keys, minified), re-hashing with BLAKE3, and checking the Ed25519 signature above."));

    let snippet: String = canonical.chars().take(1024).collect();
    doc.push(elements::Break::new(1));
    doc.push(
        elements::Paragraph::new("Canonical JSON (first 1024 chars):")
            .styled(style::Style::new().italic()),
    );
    doc.push(elements::Paragraph::new(snippet));

    doc.render_to_file(out_pdf)?;

    // Also write a .sig sidecar (detached Ed25519 over canonical JSON)
    let sig_path = decision_path.with_extension("json.sig");
    fs::write(sig_path, sig_hex)?;

    Ok(())
}
