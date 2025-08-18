fn main() {
    // This build script is used to specify files that should trigger a rebuild when modified
    
    // When api.rs changes, rerun this build script
    println!("cargo:rerun-if-changed=src/api.rs");
    
    // You can add other files that should trigger rebuilds
    println!("cargo:rerun-if-changed=src/lib.rs");
    
    // You can also run other build-time tasks here if needed
}
