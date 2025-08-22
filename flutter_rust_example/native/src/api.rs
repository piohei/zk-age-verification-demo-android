// This is the Rust API that will be exposed to Dart through flutter_rust_bridge

use std::alloc::{AllocError, Allocator, GlobalAlloc, Layout};
use std::path::PathBuf;
use std::ptr::NonNull;
use std::time::{Duration, Instant};
use std::vec;
use flutter_rust_bridge::for_generated::anyhow;
use flutter_rust_bridge::for_generated::anyhow::Context;
use anyhow::Result;
use flutter_rust_bridge::frb;
use noir_r1cs::{read, write, NoirProofScheme};
use log::info;
use crate::ALLOC;
use crate::custom_global_alloc::MemMap2File;

#[frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

pub struct CustomAllocator {
}

unsafe impl Allocator for CustomAllocator {
    fn allocate(&self, layout: Layout) -> Result<NonNull<[u8]>, AllocError> {
        info!("[zzz] Allocating!");
        match layout.size() {
            0 => Ok(NonNull::slice_from_raw_parts(layout.dangling(), 0)),
            // SAFETY: `layout` is non-zero in size,
            size => unsafe {
                info!("[zzz] Allocating! = #0");
                let ptr = ALLOC.alloc(layout);

                let ptr = NonNull::new(ptr).ok_or(AllocError)?;
                info!("[zzz] Allocating! = #1");
                let res = NonNull::slice_from_raw_parts(ptr, size);
                info!("[zzz] Allocating! = #2");
                info!("[zzz] Allocating! = #3");
                Ok(res)
            },
        }
    }

    unsafe fn deallocate(&self, ptr: NonNull<u8>, layout: Layout) {
        unsafe { ALLOC.dealloc(ptr.as_ptr(), layout) }
    }
}

#[optimize(none)]
pub fn prepare(program_path: String, output_path: String, tmp_dir_path: String) -> Result<String> {
    info!("[zzz] Prepare called!");
    let time = Instant::now();

    ALLOC.set_tmp_dir_path(tmp_dir_path.clone());

    let allocator = CustomAllocator{};

    info!("[zzz] Prepare called! - file");
    let mut file = MemMap2File::new(tmp_dir_path.into(), 1024 * 1024 * 1024 * 32);
    for i in (0..1024 * 1024 * 1024 * 16) {
        unsafe {
            let ptr = file.mmap.as_mut_ptr().add(i);
            *ptr = 1;

            // if i % (1024 * 1024 * 128) == 0 {
            //     info!("[zzz] flushing");
            //     file.flush()?;
            // }
        }
    }

    info!("[zzz] Prepare called! - vec");
    // let vec = vec!['a'; 1024 * 1024 * 512];
    let vec = vec::from_elem_in(1 as i8, 1024 * 1024 * 1024 * 8, &allocator);

    // let b: Vec<char> = vec.into_iter().map(|v| char::from_u32((v as u32) + 1).unwrap())
    //     .collect();
    //
    // println!("{:?}", b);

    // let program_path = PathBuf::from(program_path);
    // let output_path = PathBuf::from(output_path);
    //
    // let scheme = NoirProofScheme::from_file(&program_path)
    //     .context("while compiling Noir program")?;
    // write(&scheme, &output_path).context("while writing Noir proof scheme")?;

    let elapsed = time.elapsed();

    Ok(format!("Prepare done. Took: {} s", elapsed.as_secs_f32()))
}

#[optimize(none)]
pub fn prove(scheme_path: String, input_path: String, proof_path: String) -> Result<String> {
    let time = Instant::now();

    let vec = vec![vec!['a'; 1024]; 1024];

    // let scheme_path = PathBuf::from(scheme_path);
    // let input_path = PathBuf::from(input_path);
    // let proof_path = PathBuf::from(proof_path);
    //
    // // Read the scheme
    // let scheme: NoirProofScheme =
    //     read(&scheme_path).context("while reading Noir proof scheme")?;
    //
    // // Read the input toml
    // let input_map = scheme.read_witness(&input_path)?;
    //
    // // Generate the proof
    // let proof = scheme
    //     .prove(&input_map)
    //     .context("While proving Noir program statement")?;
    //
    // // Verify the proof (not in release build)
    // // #[cfg(test)]
    // // scheme
    // //     .verify(&proof)
    // //     .context("While verifying Noir proof")?;
    //
    // // Store the proof to file
    // write(&proof, &proof_path).context("while writing proof")?;

    let elapsed = time.elapsed();

    Ok(format!("Prove done. Took: {} s", elapsed.as_secs_f32()))
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
