// This is the Rust API that will be exposed to Dart through flutter_rust_bridge

use std::alloc::GlobalAlloc;
use std::path::PathBuf;
use std::time::Instant;
use flutter_rust_bridge::for_generated::anyhow;
use flutter_rust_bridge::for_generated::anyhow::Context;
use anyhow::Result;
use flutter_rust_bridge::frb;
use provekit_common::{file::read, NoirProofScheme};
use provekit_prover::NoirProofSchemeProver;
use log::info;
use crate::ALLOC;
use crate::remote::verify;

#[frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

pub fn prove(
    scheme_path: String,
    input_path: String,
    proof_path: String,
    tmp_dir_path: String,
    sod: Vec<u8>,
    dg1: Vec<u8>,
) -> Result<String> {
    let time = Instant::now();

    ALLOC.set_tmp_dir_path(tmp_dir_path.clone());

    let scheme_path = PathBuf::from(scheme_path);
    let input_path = PathBuf::from(input_path);
    let proof_path = PathBuf::from(proof_path);

    info!("Reading NPS - start");
    // Read the scheme
    let scheme: NoirProofScheme =
        read(&scheme_path).context("while reading Noir proof scheme")?;
    info!("Reading NPS - end");

    // Read the input toml
    let input_map = scheme.read_witness(&input_path)?;

    info!("Prove method - start");
    // Generate the proof
    let proof = scheme
        .prove(&input_map)
        .context("While proving Noir program statement")?;
    info!("Prove method - end");

    // Verify the proof (not in release build)
    // #[cfg(test)]
    // scheme
    //     .verify(&proof)
    //     .context("While verifying Noir proof")?;

    // Store the proof to file
    // write(&proof, &proof_path).context("while writing proof")?;

    // let resp = verify(proof)?;

    let elapsed = time.elapsed();

    // Ok(format!("Prove done. Took: {} s. Server response: {}", elapsed.as_secs_f32(), resp.status()))
    Ok(format!("Prove done. Took: {} s. Server response: none", elapsed.as_secs_f32()))
}