use anyhow::Result;
use std::collections::HashMap;
use flutter_rust_bridge::for_generated::anyhow;
use provekit_common::NoirProof;
use reqwest::blocking;
use reqwest::blocking::Response;
use serde::{Deserialize, Serialize};

/// Request payload for proof verification
#[derive(Debug, Clone, Deserialize, Serialize)]
struct VerifyRequest {
    /// URL to the Noir Proof Scheme file (.nps)
    #[serde(rename = "npsUrl")]
    pub nps_url:             String,
    /// JSON encoded NoirProof (.np file content)
    pub np:                  NoirProof,
    /// URL to the R1CS file
    #[serde(rename = "r1csUrl")]
    pub r1cs_url:            String,
    /// URL to the proving key file
    #[serde(rename = "pkUrl")]
    pub pk_url:              String,
    /// URL to the verification key file
    #[serde(rename = "vkUrl")]
    pub vk_url:              String,
    /// Optional verification parameters
    #[serde(rename = "verificationParams")]
    pub verification_params: Option<VerificationParams>,
    /// Request metadata
    #[serde(default)]
    pub metadata:            Option<RequestMetadata>,
}


/// Verification parameters
#[derive(Debug, Clone, Default, Deserialize, Serialize)]
struct VerificationParams {
    /// Maximum verification time in seconds
    #[serde(rename = "maxVerificationTime")]
    pub max_verification_time: u64,
    /// Additional verification options
    #[serde(default)]
    pub options:               HashMap<String, serde_json::Value>,
}

/// Request metadata
#[derive(Debug, Clone, Default, Deserialize, Serialize)]
struct RequestMetadata {
    /// Client identifier
    #[serde(rename = "clientId")]
    pub client_id:     Option<String>,
    /// Request timestamp (ISO 8601)
    pub timestamp:     Option<String>,
    /// Request ID for tracking
    #[serde(rename = "requestId")]
    pub request_id:    Option<String>,
    /// Additional custom fields
    #[serde(default)]
    #[serde(rename = "customFields")]
    pub custom_fields: HashMap<String, serde_json::Value>,
}

pub fn verify(proof: NoirProof) -> Result<Response> {
    let client = blocking::Client::new();
    Ok(client
        .post("http://localhost:3000/verify")
        .json(&VerifyRequest{
            nps_url: "http://localhost:3000/scheme.nps".to_string(),
            r1cs_url: "http://localhost:3000/r1cs.json".to_string(),
            pk_url: "http://localhost:3000/proving_key.bin".to_string(),
            vk_url: "http://localhost:3000/verification_key.bin".to_string(),
            np: proof,
            verification_params: Some(VerificationParams{
                max_verification_time: 300,
                options: Default::default(),
            }),
            metadata: None,
        })
        .send()?)
}