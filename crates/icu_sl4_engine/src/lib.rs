use anyhow::{anyhow, Result};
use ed25519_dalek::{Signature, Signer, SigningKey, VerifyingKey};
use once_cell::sync::Lazy;
use regex::Regex;
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::path::Path;

// -----------------------------
// Types
// -----------------------------

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Input {
    pub text: String,
    #[serde(default)]
    pub measured: BTreeMap<String, f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Action {
    pub name: String,
    pub max_delay_s: u64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub deadline_s: Option<u64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "UPPERCASE")]
pub enum Severity {
    CRITICAL,
    URGENT,
    ROUTINE,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Ast {
    pub severity: Severity,
    pub signals: Vec<String>,
    pub protocols: Vec<String>,
    pub actions: Vec<Action>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub normative: Option<BTreeMap<String, String>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Decision {
    pub sensitivity_bias: String,
    pub require_human_ack: bool,
    pub actions: Vec<Action>,
    pub hazards: Vec<String>,
    pub watchdog_armed: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Policy {
    pub protocol_id: String,
    pub version: String,
    pub jurisdiction: String,
    pub source: String,
    pub triggers: Vec<String>,
    pub severity: Severity,
    pub actions: Vec<Action>,
    #[serde(default)]
    pub normative_references: Vec<String>,
}

// -----------------------------
// Deterministic helpers
// -----------------------------

/// Canonical JSON: sorted keys, no whitespace.
pub fn json_canonical(obj: &serde_json::Value) -> Result<String> {
    fn sort_value(v: &serde_json::Value) -> serde_json::Value {
        match v {
            serde_json::Value::Object(map) => {
                let mut b = BTreeMap::new();
                for (k, vv) in map.iter() {
                    b.insert(k.clone(), sort_value(vv));
                }
                serde_json::Value::Object(b.into_iter().collect())
            }
            serde_json::Value::Array(arr) => {
                serde_json::Value::Array(arr.iter().map(sort_value).collect())
            }
            _ => v.clone(),
        }
    }
    let sorted = sort_value(obj);
    let s = serde_json::to_string(&sorted)?; // minified
    Ok(s)
}

pub fn blake3_hash_str(s: &str) -> String {
    let h = blake3::hash(s.as_bytes());
    let hex = h.to_hex();
    format!("blake3:{hex}")
}

pub fn blake3_hash_json(obj: &serde_json::Value) -> Result<String> {
    Ok(blake3_hash_str(&json_canonical(obj)?))
}

// -----------------------------
// Dual-channel TDLN micro-impl
// -----------------------------

static RE_HYPOX: Lazy<Regex> = Lazy::new(|| Regex::new(r"(?i)hipox[eê]mia|hypox").unwrap());
static RE_TACHY: Lazy<Regex> = Lazy::new(|| Regex::new(r"(?i)taqui|tachy").unwrap());
static RE_DIAPHO: Lazy<Regex> = Lazy::new(|| Regex::new(r"(?i)sudorese|diaphores").unwrap());

pub fn tdln_channel_a(input: &Input) -> Ast {
    let mut signals = BTreeSet::new();
    let mut actions: Vec<Action> = Vec::new();
    let text = input.text.as_str();

    if RE_HYPOX.is_match(text)
        || input
            .measured
            .get("spo2_pct")
            .map(|v| *v < 90.0)
            .unwrap_or(false)
    {
        signals.insert("hypoxemia".to_string());
    }
    if input
        .measured
        .get("spo2_pct")
        .map(|v| *v < 85.0)
        .unwrap_or(false)
    {
        signals.insert("severe_hypoxemia".to_string());
    }
    if RE_TACHY.is_match(text)
        || input
            .measured
            .get("hr_bpm")
            .map(|v| *v > 100.0)
            .unwrap_or(false)
    {
        signals.insert("tachycardia".to_string());
    }
    if RE_DIAPHO.is_match(text) {
        signals.insert("diaphoresis".to_string());
    }

    if signals.contains("hypoxemia") {
        actions.push(Action {
            name: "increase_O2_100".into(),
            max_delay_s: 0,
            deadline_s: None,
        });
        actions.push(Action {
            name: "call_attending".into(),
            max_delay_s: 30,
            deadline_s: None,
        });
        if signals.contains("severe_hypoxemia") {
            actions.push(Action {
                name: "prepare_intubation_kit".into(),
                max_delay_s: 60,
                deadline_s: None,
            });
        }
    }

    actions.sort_by(|a, b| a.name.cmp(&b.name));

    let severity = if signals.contains("severe_hypoxemia") {
        Severity::CRITICAL
    } else if signals.contains("hypoxemia") || signals.contains("tachycardia") {
        Severity::URGENT
    } else {
        Severity::ROUTINE
    };

    Ast {
        severity: severity.clone(),
        signals: signals.into_iter().collect(),
        protocols: if severity != Severity::ROUTINE {
            vec!["hypoxemia_acute".into()]
        } else {
            vec![]
        },
        actions,
        normative: None,
    }
}

pub fn tdln_channel_b(input: &Input) -> Ast {
    let mut s = BTreeSet::new();
    let mut a: Vec<Action> = Vec::new();

    let spo2 = input.measured.get("spo2_pct").copied();
    let hr = input.measured.get("hr_bpm").copied();
    let text = input.text.as_str();

    if spo2.map(|v| v < 90.0).unwrap_or(false) || RE_HYPOX.is_match(text) {
        s.insert("hypoxemia".to_string());
    }
    if spo2.map(|v| v < 85.0).unwrap_or(false) {
        s.insert("severe_hypoxemia".to_string());
    }
    if hr.map(|v| v > 100.0).unwrap_or(false) || RE_TACHY.is_match(text) {
        s.insert("tachycardia".to_string());
    }
    if RE_DIAPHO.is_match(text) {
        s.insert("diaphoresis".to_string());
    }

    if s.contains("hypoxemia") {
        a.extend_from_slice(&[
            Action {
                name: "increase_O2_100".into(),
                max_delay_s: 0,
                deadline_s: None,
            },
            Action {
                name: "call_attending".into(),
                max_delay_s: 30,
                deadline_s: None,
            },
        ]);
        if s.contains("severe_hypoxemia") {
            a.push(Action {
                name: "prepare_intubation_kit".into(),
                max_delay_s: 60,
                deadline_s: None,
            });
        }
    }

    a.sort_by(|x, y| x.name.cmp(&y.name));

    let sev = if s.contains("severe_hypoxemia") {
        Severity::CRITICAL
    } else if s.contains("hypoxemia") || s.contains("tachycardia") {
        Severity::URGENT
    } else {
        Severity::ROUTINE
    };

    Ast {
        severity: sev.clone(),
        signals: s.into_iter().collect(),
        protocols: if sev != Severity::ROUTINE {
            vec!["hypoxemia_acute".into()]
        } else {
            vec![]
        },
        actions: a,
        normative: None,
    }
}

// -----------------------------
// Policy & Decision
// -----------------------------

pub fn apply_policy(ast: &Ast, p: &Policy) -> Decision {
    let mut actions: Vec<Action> = p
        .actions
        .iter()
        .map(|a| Action {
            name: a.name.clone(),
            max_delay_s: a.max_delay_s,
            deadline_s: Some(a.max_delay_s),
        })
        .collect();
    actions.sort_by(|a, b| a.name.cmp(&b.name));

    Decision {
        sensitivity_bias: "ZFN".to_string(),
        require_human_ack: matches!(ast.severity, Severity::CRITICAL | Severity::URGENT),
        actions,
        hazards: match ast.severity {
            Severity::CRITICAL => vec!["HYPOXEMIA_CRITICAL".into()],
            Severity::URGENT => vec!["HYPOXEMIA_MODERATE".into()],
            Severity::ROUTINE => vec![],
        },
        watchdog_armed: false,
    }
}

// -----------------------------
/* Proof pack & ledger */
// -----------------------------

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProofPack {
    pub input_hash: String,
    pub ast_hash: String,
    pub policy_hash: String,
    pub binary_hash: String,
    pub config_hash: String,
    pub decision_time: String,     // RFC3339
    pub tsa_token: Option<String>, // RFC 3161 (stub)
    pub sign: SignatureBlock,
    pub link_prev: Option<String>, // previous ledger entry hash (blockstamp)
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SignatureBlock {
    pub alg: String,
    pub pubkey: String,
    pub sig: String,
}

pub fn load_policy_yaml(path: &Path) -> Result<Policy> {
    let s = fs::read_to_string(path)?;
    Ok(serde_yaml::from_str(&s)?)
}

pub fn keypair_from_json(path: &Path) -> Result<(SigningKey, VerifyingKey)> {
    #[derive(Deserialize)]
    struct KeyFile {
        pub secret_hex: String,
    }
    let s = fs::read_to_string(path)?;
    let k: KeyFile = serde_json::from_str(&s)?;
    let sk_bytes = hex::decode(k.secret_hex).map_err(|e| anyhow!("hex decode: {e}"))?;
    let sk = SigningKey::from_bytes(&sk_bytes.try_into().map_err(|_| anyhow!("bad key length"))?);
    let vk = sk.verifying_key();
    Ok((sk, vk))
}

pub fn verifying_key_to_hex(vk: &VerifyingKey) -> String {
    hex::encode(vk.to_bytes())
}

pub fn sign_bytes(sk: &SigningKey, msg: &[u8]) -> Signature {
    sk.sign(msg)
}

pub fn verify_bytes(vk: &VerifyingKey, msg: &[u8], sig: &Signature) -> Result<()> {
    vk.verify_strict(msg, sig)
        .map_err(|e| anyhow!("verify failed: {e}"))
}

pub fn make_proof_pack(
    input: &Input,
    ast: &Ast,
    policy_hash: &str,
    binary_hash: &str,
    config_hash: &str,
    decision_time: &str,
    sign_key: &SigningKey,
) -> Result<ProofPack> {
    let input_v = serde_json::to_value(input)?;
    let ast_v = serde_json::to_value(ast)?;
    let input_hash = blake3_hash_json(&input_v)?;
    let ast_hash = blake3_hash_json(&ast_v)?;

    let unsigned = json!({
        "input_hash": input_hash,
        "ast_hash": ast_hash,
        "policy_hash": policy_hash,
        "binary_hash": binary_hash,
        "config_hash": config_hash,
        "decision_time": decision_time,
        "tsa_token": serde_json::Value::Null,
        "sign": serde_json::Value::Null,
        "link_prev": serde_json::Value::Null,
    });
    let canonical = json_canonical(&unsigned)?;
    let sig = sign_bytes(sign_key, canonical.as_bytes());
    let sig_hex = hex::encode(sig.to_bytes());

    let pp = ProofPack {
        input_hash,
        ast_hash,
        policy_hash: policy_hash.to_string(),
        binary_hash: binary_hash.to_string(),
        config_hash: config_hash.to_string(),
        decision_time: decision_time.to_string(),
        tsa_token: None,
        sign: SignatureBlock {
            alg: "Ed25519".into(),
            pubkey: verifying_key_to_hex(&sign_key.verifying_key()),
            sig: sig_hex,
        },
        link_prev: None,
    };
    Ok(pp)
}

// -----------------------------
// Frontier certificate
// -----------------------------

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FrontierCert {
    pub feature: String,
    pub threshold: f64,
    pub relation: String, // "<", ">", "<=", ">="
    pub margin_to_flip: f64,
}

pub fn frontier_for_hypoxemia(input: &Input) -> Vec<FrontierCert> {
    let mut out = vec![];
    if let Some(spo2) = input.measured.get("spo2_pct").copied() {
        let thr = 90.0;
        let margin = if spo2 < thr { thr - spo2 } else { spo2 - thr };
        out.push(FrontierCert {
            feature: "spo2_pct".into(),
            threshold: 90.0,
            relation: "<".to_string(),
            margin_to_flip: margin,
        });
        if spo2 < 85.0 {
            out.push(FrontierCert {
                feature: "spo2_pct".into(),
                threshold: 85.0,
                relation: "<".to_string(),
                margin_to_flip: 85.0 - spo2,
            });
        }
    }
    if let Some(hr) = input.measured.get("hr_bpm").copied() {
        let thr = 100.0;
        let margin = if hr > thr { hr - thr } else { thr - hr };
        out.push(FrontierCert {
            feature: "hr_bpm".into(),
            threshold: 100.0,
            relation: ">".to_string(),
            margin_to_flip: margin,
        });
    }
    out
}

// -----------------------------
// Public API
// -----------------------------

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DecideOutput {
    pub ast: Ast,
    pub decision: Decision,
    pub proof_pack: ProofPack,
    pub frontier: Vec<FrontierCert>,
}

pub fn decide(
    input: &Input,
    policy: &Policy,
    binary_hash: &str,
    config_hash: &str,
    sign_key: &SigningKey,
    now_rfc3339: &str,
) -> Result<DecideOutput> {
    let a = tdln_channel_a(input);
    let b = tdln_channel_b(input);
    if a.actions != b.actions || a.severity != b.severity {
        return Err(anyhow!("dual-channel divergence; entering safe mode"));
    }
    let decision = apply_policy(&a, policy);
    let policy_v = serde_json::to_value(policy)?;
    let policy_hash = blake3_hash_json(&policy_v)?;

    let proof = make_proof_pack(
        input,
        &a,
        &policy_hash,
        binary_hash,
        config_hash,
        now_rfc3339,
        sign_key,
    )?;
    let frontier = frontier_for_hypoxemia(input);
    Ok(DecideOutput {
        ast: a,
        decision,
        proof_pack: proof,
        frontier,
    })
}

// Ledger append-only NDJSON with blockstamp
pub fn ledger_append<P: AsRef<Path>>(path: P, entry: &serde_json::Value) -> Result<String> {
    let s = crate::json_canonical(entry)?;
    let h = crate::blake3_hash_str(&s);
    let line_obj = json!({
        "hash": h,
        "entry": serde_json::from_str::<serde_json::Value>(&s)?
    });
    fs::create_dir_all(path.as_ref().parent().unwrap_or(Path::new(".")))?;
    let mut f = fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(&path)?;
    use std::io::Write;
    writeln!(f, "{}", serde_json::to_string(&line_obj)?)?;
    Ok(h)
}
