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
use crate::ALLOC;
use crate::remote::verify;

#[frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

pub fn prove(
    scheme_path: String, input_path: String, proof_path: String, tmp_dir_path: String
) -> Result<String> {
    let time = Instant::now();

    ALLOC.set_tmp_dir_path(tmp_dir_path.clone());

    let scheme_path = PathBuf::from(scheme_path);
    let input_path = PathBuf::from(input_path);
    let proof_path = PathBuf::from(proof_path);

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

    let resp = verify(proof)?;

    let elapsed = time.elapsed();

    Ok(format!("Prove done. Took: {} s. Server response: {}", elapsed.as_secs_f32(), resp.status()))
}