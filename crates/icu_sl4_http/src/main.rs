use actix_web::{get, post, web, App, HttpResponse, HttpServer, Responder};
use icu_sl4_engine::*;
use serde::{Deserialize, Serialize};
use time::OffsetDateTime;
use utoipa::{OpenApi, ToSchema};
use utoipa_swagger_ui::SwaggerUi;

// -----------------------------
// OpenAPI Types - Wrappers for engine types
// -----------------------------

// Wrapper types with ToSchema for OpenAPI documentation
#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
pub struct InputSchema {
    #[schema(example = "paciente com saturação 85%, taquicárdico, sudorese")]
    pub text: String,
    #[schema(example = r#"{"spo2_pct": 85, "hr_bpm": 125}"#)]
    #[serde(default)]
    pub measured: std::collections::BTreeMap<String, f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
pub struct ActionSchema {
    #[schema(example = "increase_O2_100")]
    pub name: String,
    #[schema(example = 0)]
    pub max_delay_s: u64,
    #[schema(example = 0)]
    pub deadline_s: Option<u64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "UPPERCASE")]
pub enum SeveritySchema {
    CRITICAL,
    URGENT,
    ROUTINE,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
pub struct AstSchema {
    pub severity: SeveritySchema,
    #[schema(example = r#"["hypoxemia", "tachycardia"]"#)]
    pub signals: Vec<String>,
    #[schema(example = r#"["hypoxemia_acute"]"#)]
    pub protocols: Vec<String>,
    pub actions: Vec<ActionSchema>,
    pub normative: Option<std::collections::BTreeMap<String, String>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
pub struct DecisionSchema {
    #[schema(example = "ZFN")]
    pub sensitivity_bias: String,
    pub require_human_ack: bool,
    pub actions: Vec<ActionSchema>,
    #[schema(example = r#"["HYPOXEMIA_CRITICAL"]"#)]
    pub hazards: Vec<String>,
    pub watchdog_armed: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
pub struct DecideReq {
    #[schema(value_type = InputSchema, example = r#"{"text": "paciente com saturação 85%", "measured": {"spo2_pct": 85, "hr_bpm": 125}}"#)]
    pub input: Input,
    /// Política em YAML (texto)
    #[schema(example = "---\nprotocol_id: hypoxemia_acute\nversion: 1.0.0\n")]
    pub policy_yaml: String,
    /// Chave secreta Ed25519 (hex de 32 bytes) — DEV ONLY; em produção use HSM/KMS
    #[schema(example = "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f")]
    pub keypair_secret_hex: String,
    /// Hash do binário (string) para pin de build (opcional)
    #[schema(example = "blake3:http-demo@0.1.0")]
    pub binary_hash: Option<String>,
    /// Hash de config (string) para pin de config (opcional)
    #[schema(example = "blake3:prod-euwest")]
    pub config_hash: Option<String>,
    /// Caminho para ledger NDJSON (opcional); se informado, o servidor apenda a decisão
    pub ledger_path: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
pub struct VerifyReq {
    #[schema(
        example = r#"{"proof_pack": {"input_hash": "...", "sign": {"sig": "...", "pubkey": "..."}}}"#
    )]
    pub decision: serde_json::Value,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
pub struct VerifyResp {
    pub ok: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
pub struct TsaAnchorResp {
    pub ok: bool,
    pub token: String,
}

// FHIR Observation types (simplified)
#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
pub struct FhirObservation {
    #[schema(example = "Observation")]
    pub resource_type: String,
    #[schema(example = "obs-123")]
    pub id: Option<String>,
    pub status: Option<String>,
    pub code: Option<FhirCodeableConcept>,
    pub effective_date_time: Option<String>,
    pub value_quantity: Option<FhirQuantity>,
    pub component: Option<Vec<FhirObservationComponent>>,
    pub note: Option<Vec<FhirAnnotation>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
pub struct FhirCodeableConcept {
    pub coding: Option<Vec<FhirCoding>>,
    pub text: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
pub struct FhirCoding {
    pub system: Option<String>,
    pub code: Option<String>,
    pub display: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
pub struct FhirQuantity {
    pub value: Option<f64>,
    pub unit: Option<String>,
    pub system: Option<String>,
    pub code: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
pub struct FhirObservationComponent {
    pub code: Option<FhirCodeableConcept>,
    pub value_quantity: Option<FhirQuantity>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
pub struct FhirAnnotation {
    pub text: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
pub struct FhirDecideReq {
    pub observation: FhirObservation,
    pub policy_yaml: String,
    pub keypair_secret_hex: String,
    pub binary_hash: Option<String>,
    pub config_hash: Option<String>,
    pub ledger_path: Option<String>,
}

// -----------------------------
// FHIR to Input conversion
// -----------------------------

fn fhir_observation_to_input(obs: &FhirObservation) -> Input {
    let mut text_parts = Vec::new();
    let mut measured = std::collections::BTreeMap::new();

    // Extract text from note
    if let Some(notes) = &obs.note {
        for note in notes {
            if let Some(t) = &note.text {
                text_parts.push(t.clone());
            }
        }
    }

    // Extract main value
    if let Some(qty) = &obs.value_quantity {
        if let Some(v) = qty.value {
            if let Some(code) = &obs.code {
                if let Some(codings) = &code.coding {
                    for coding in codings {
                        if let Some(c) = &coding.code {
                            match c.as_str() {
                                "2708-6" | "http://loinc.org|2708-6" => {
                                    // SpO2
                                    measured.insert("spo2_pct".to_string(), v);
                                    if let Some(display) = &coding.display {
                                        text_parts.push(format!("{display}: {v}%"));
                                    }
                                }
                                "8867-4" | "http://loinc.org|8867-4" => {
                                    // Heart rate
                                    measured.insert("hr_bpm".to_string(), v);
                                    if let Some(display) = &coding.display {
                                        text_parts.push(format!("{display}: {v} bpm"));
                                    }
                                }
                                _ => {
                                    // Generic numeric observation
                                    if let Some(display) = &coding.display {
                                        text_parts.push(format!("{display}: {v}"));
                                    }
                                }
                            }
                        }
                    }
                }
                if let Some(t) = &code.text {
                    text_parts.push(t.clone());
                }
            }
        }
    }

    // Extract component values
    if let Some(components) = &obs.component {
        for comp in components {
            if let Some(qty) = &comp.value_quantity {
                if let Some(v) = qty.value {
                    if let Some(code) = &comp.code {
                        if let Some(codings) = &code.coding {
                            for coding in codings {
                                if let Some(c) = &coding.code {
                                    match c.as_str() {
                                        "2708-6" | "http://loinc.org|2708-6" => {
                                            measured.insert("spo2_pct".to_string(), v);
                                        }
                                        "8867-4" | "http://loinc.org|8867-4" => {
                                            measured.insert("hr_bpm".to_string(), v);
                                        }
                                        _ => {}
                                    }
                                }
                                if let Some(display) = &coding.display {
                                    text_parts.push(format!("{display}: {v}"));
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    let text = if text_parts.is_empty() {
        "FHIR Observation".to_string()
    } else {
        text_parts.join(", ")
    };

    Input { text, measured }
}

// -----------------------------
// Endpoints
// -----------------------------

#[utoipa::path(
    post,
    path = "/decide",
    request_body = DecideReq,
    responses(
        (status = 200, description = "Decision made successfully", body = serde_json::Value),
        (status = 400, description = "Bad request")
    ),
    tag = "Decision"
)]
#[post("/decide")]
async fn decide_ep(body: web::Json<DecideReq>) -> impl Responder {
    let policy: Policy = match serde_yaml::from_str(&body.policy_yaml) {
        Ok(p) => p,
        Err(e) => return HttpResponse::BadRequest().body(format!("policy parse error: {e}")),
    };

    let sk_bytes = match hex::decode(&body.keypair_secret_hex) {
        Ok(b) if b.len() == 32 => b,
        _ => return HttpResponse::BadRequest().body("keypair_secret_hex must be 32-byte hex"),
    };
    let sk = ed25519_dalek::SigningKey::from_bytes(&sk_bytes.try_into().unwrap());

    let now = OffsetDateTime::now_utc()
        .format(&time::format_description::well_known::Rfc3339)
        .unwrap();
    let bin = body
        .binary_hash
        .clone()
        .unwrap_or_else(|| "blake3:http-demo-binary".into());
    let cfg = body
        .config_hash
        .clone()
        .unwrap_or_else(|| "blake3:http-demo-config".into());

    let d = match decide(&body.input, &policy, &bin, &cfg, &sk, &now) {
        Ok(v) => v,
        Err(e) => return HttpResponse::BadRequest().body(format!("decision error: {e}")),
    };

    let decision_v = serde_json::json!({
        "ast": d.ast,
        "decision": d.decision,
        "proof_pack": d.proof_pack,
        "frontier": d.frontier,
    });

    if let Some(path) = &body.ledger_path {
        if let Err(e) = icu_sl4_engine::ledger_append(path, &decision_v) {
            eprintln!("ledger append failed: {e}");
        }
    }

    HttpResponse::Ok().json(decision_v)
}

#[utoipa::path(
    post,
    path = "/fhir/observation",
    request_body = FhirDecideReq,
    responses(
        (status = 200, description = "Decision made from FHIR Observation", body = serde_json::Value),
        (status = 400, description = "Bad request")
    ),
    tag = "FHIR"
)]
#[post("/fhir/observation")]
async fn fhir_observation_ep(body: web::Json<FhirDecideReq>) -> impl Responder {
    let input = fhir_observation_to_input(&body.observation);

    let policy: Policy = match serde_yaml::from_str(&body.policy_yaml) {
        Ok(p) => p,
        Err(e) => return HttpResponse::BadRequest().body(format!("policy parse error: {e}")),
    };

    let sk_bytes = match hex::decode(&body.keypair_secret_hex) {
        Ok(b) if b.len() == 32 => b,
        _ => return HttpResponse::BadRequest().body("keypair_secret_hex must be 32-byte hex"),
    };
    let sk = ed25519_dalek::SigningKey::from_bytes(&sk_bytes.try_into().unwrap());

    let now = OffsetDateTime::now_utc()
        .format(&time::format_description::well_known::Rfc3339)
        .unwrap();
    let bin = body
        .binary_hash
        .clone()
        .unwrap_or_else(|| "blake3:http-demo-binary".into());
    let cfg = body
        .config_hash
        .clone()
        .unwrap_or_else(|| "blake3:http-demo-config".into());

    let d = match decide(&input, &policy, &bin, &cfg, &sk, &now) {
        Ok(v) => v,
        Err(e) => return HttpResponse::BadRequest().body(format!("decision error: {e}")),
    };

    let decision_v = serde_json::json!({
        "ast": d.ast,
        "decision": d.decision,
        "proof_pack": d.proof_pack,
        "frontier": d.frontier,
        "fhir_observation_id": body.observation.id.clone(),
    });

    if let Some(path) = &body.ledger_path {
        if let Err(e) = icu_sl4_engine::ledger_append(path, &decision_v) {
            eprintln!("ledger append failed: {e}");
        }
    }

    HttpResponse::Ok().json(decision_v)
}

#[utoipa::path(
    post,
    path = "/verify",
    request_body = VerifyReq,
    responses(
        (status = 200, description = "Signature valid", body = VerifyResp),
        (status = 400, description = "Verification failed")
    ),
    tag = "Verification"
)]
#[post("/verify")]
async fn verify_ep(body: web::Json<VerifyReq>) -> impl Responder {
    let v = &body.decision;
    let pp = &v["proof_pack"];

    let unsigned = serde_json::json!({
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
    let canonical = match json_canonical(&unsigned) {
        Ok(c) => c,
        Err(e) => return HttpResponse::BadRequest().body(format!("canonical error: {e}")),
    };

    let sig_hex = match pp["sign"]["sig"].as_str() {
        Some(s) => s,
        None => return HttpResponse::BadRequest().body("missing sign.sig"),
    };
    let pub_hex = match pp["sign"]["pubkey"].as_str() {
        Some(s) => s,
        None => return HttpResponse::BadRequest().body("missing sign.pubkey"),
    };

    let sig_bytes = match hex::decode(sig_hex) {
        Ok(b) => b,
        Err(_) => return HttpResponse::BadRequest().body("bad sig hex"),
    };
    let pk_bytes = match hex::decode(pub_hex) {
        Ok(b) => b,
        Err(_) => return HttpResponse::BadRequest().body("bad pub hex"),
    };

    let sig = ed25519_dalek::Signature::from_bytes(&sig_bytes.try_into().unwrap_or([0u8; 64]));
    let vk =
        match ed25519_dalek::VerifyingKey::from_bytes(&pk_bytes.try_into().unwrap_or([0u8; 32])) {
            Ok(v) => v,
            Err(_) => return HttpResponse::BadRequest().body("bad pubkey length"),
        };

    if let Err(e) = verify_bytes(&vk, canonical.as_bytes(), &sig) {
        return HttpResponse::BadRequest().body(format!("verify failed: {e}"));
    }
    HttpResponse::Ok().json(VerifyResp { ok: true })
}

#[utoipa::path(
    post,
    path = "/tsa/anchor",
    request_body(content = String, description = "Ledger head hash"),
    responses(
        (status = 200, description = "Temporal anchor token generated", body = TsaAnchorResp)
    ),
    tag = "TSA"
)]
#[post("/tsa/anchor")]
async fn tsa_anchor(body: String) -> impl Responder {
    // Very simple stub: expect plain ledger_head string
    let head = body.trim().to_string();
    let now = OffsetDateTime::now_utc()
        .format(&time::format_description::well_known::Rfc3339)
        .unwrap();
    let token = format!(
        "rfc3161:stub:{}:{}",
        now,
        &head.chars().take(16).collect::<String>()
    );
    HttpResponse::Ok().json(TsaAnchorResp { ok: true, token })
}

#[utoipa::path(
    get,
    path = "/healthz",
    responses(
        (status = 200, description = "Service is healthy")
    ),
    tag = "Health"
)]
#[get("/healthz")]
async fn healthz() -> impl Responder {
    "ok"
}

#[derive(OpenApi)]
#[openapi(
    paths(
        decide_ep,
        fhir_observation_ep,
        verify_ep,
        tsa_anchor,
        healthz
    ),
    components(schemas(
        DecideReq,
        VerifyReq,
        VerifyResp,
        TsaAnchorResp,
        FhirObservation,
        FhirCodeableConcept,
        FhirCoding,
        FhirQuantity,
        FhirObservationComponent,
        FhirAnnotation,
        FhirDecideReq,
        InputSchema,
        ActionSchema,
        SeveritySchema,
        AstSchema,
        DecisionSchema
    )),
    tags(
        (name = "Decision", description = "Decision making endpoints"),
        (name = "FHIR", description = "FHIR integration endpoints"),
        (name = "Verification", description = "Signature verification endpoints"),
        (name = "TSA", description = "Temporal anchoring endpoints"),
        (name = "Health", description = "Health check endpoints")
    ),
    info(
        title = "ICU SL4 API",
        description = "Deterministic ICU decision engine with cryptographic proof",
        version = "0.1.0"
    )
)]
struct ApiDoc;

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let port = std::env::var("PORT")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(8787);
    println!("icu_sl4_http listening on :{port}");
    println!("OpenAPI docs available at: http://localhost:{port}/swagger-ui/");

    HttpServer::new(|| {
        App::new()
            .service(healthz)
            .service(decide_ep)
            .service(fhir_observation_ep)
            .service(verify_ep)
            .service(tsa_anchor)
            .service(
                SwaggerUi::new("/swagger-ui/{_:.*}")
                    .url("/api-doc/openapi.json", ApiDoc::openapi()),
            )
    })
    .bind(("0.0.0.0", port))?
    .run()
    .await
}
