// This is the Rust API that will be exposed to Dart through flutter_rust_bridge

use std::alloc::GlobalAlloc;
use std::path::PathBuf;
use std::time::Instant;
use flutter_rust_bridge::for_generated::anyhow;
use flutter_rust_bridge::for_generated::anyhow::Context;
use anyhow::Result;
use flutter_rust_bridge::frb;
use noir_r1cs::{create_io_pattern, read, write, write_gnark_parameters_to_file, NoirProof, NoirProofScheme};
use reqwest::blocking;
use crate::ALLOC;

#[frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

pub fn prove(
    scheme_path: String, input_path: String, gnark_inputs_path: String, tmp_dir_path: String
) -> Result<String> {
    let time = Instant::now();

    ALLOC.set_tmp_dir_path(tmp_dir_path.clone());

    let scheme_path = PathBuf::from(scheme_path);
    let input_path = PathBuf::from(input_path);
    let gnark_inputs_path = PathBuf::from(gnark_inputs_path);

    // Read the scheme
    let scheme: NoirProofScheme =
        read(&scheme_path).context("while reading Noir proof scheme")?;

    // Read the input toml
    let input_map = scheme.read_witness(&input_path)?;

    // Generate the proof
    let proof = scheme
        .prove(&input_map)
        .context("While proving Noir program statement")?;

    // Verify the proof (not in release build)
    // #[cfg(test)]
    // scheme
    //     .verify(&proof)
    //     .context("While verifying Noir proof")?;

    // Store the proof to file
    // write(&proof, &proof_path).context("while writing proof")?;

    generate_gnark_inputs(&scheme, &proof, &gnark_inputs_path);

    let form = blocking::multipart::Form::new()
        .file("config", &gnark_inputs_path)?;
    let client = blocking::Client::new();
    let resp = client
        .post("http://34.55.192.39/api/v1/verifyagecheck")
        .multipart(form)
        .send()?;

    let elapsed = time.elapsed();

    Ok(format!("Prove done. Took: {} s. Server response: {}", elapsed.as_secs_f32(), resp.status()))
}

fn generate_gnark_inputs(
    noir_proof_scheme: &NoirProofScheme, noir_proof: &NoirProof, gnark_inputs_path: &PathBuf,
) {
    write_gnark_parameters_to_file(
        &noir_proof_scheme.whir.whir_config,
        &noir_proof.whir_r1cs_proof.transcript,
        &create_io_pattern(noir_proof_scheme.whir.m_0, &noir_proof_scheme.whir.whir_config),
        noir_proof.whir_r1cs_proof.whir_query_answer_sums,
        noir_proof_scheme.whir.m_0,
        noir_proof_scheme.whir.m,
        gnark_inputs_path.to_str().unwrap(),
    );
}