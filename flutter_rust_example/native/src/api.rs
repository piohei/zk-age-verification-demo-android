// This is the Rust API that will be exposed to Dart through flutter_rust_bridge

use std::path::PathBuf;
use flutter_rust_bridge::for_generated::anyhow;
use flutter_rust_bridge::for_generated::anyhow::Context;
use anyhow::Result;
use noir_r1cs::{read, write, NoirProofScheme};

pub fn prepare(program_path: String, output_path: String) -> Result<String> {
    let program_path = PathBuf::from(program_path);
    let output_path = PathBuf::from(output_path);

    let scheme = NoirProofScheme::from_file(&program_path)
        .context("while compiling Noir program")?;
    write(&scheme, &output_path).context("while writing Noir proof scheme")?;

    Ok("Prepare done".to_string())
}

pub fn prove(scheme_path: String, input_path: String, proof_path: String) -> Result<String> {
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
    write(&proof, &proof_path).context("while writing proof")?;

    Ok("Prove done".to_string())
}

// We could add more functions here as needed
// Example:
// 
// pub fn add_numbers(a: i32, b: i32) -> i32 {
//     a + b
// }
// 
// pub struct Person {
//     pub name: String,
//     pub age: i32,
// }
// 
// pub fn create_person(name: String, age: i32) -> Person {
//     Person { name, age }
// }
