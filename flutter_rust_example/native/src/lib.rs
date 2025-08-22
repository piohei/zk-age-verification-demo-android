#![feature(optimize_attribute)]
#![feature(allocator_api)]
#![feature(alloc_layout_extra)]

use std::alloc::{GlobalAlloc, System};
use crate::custom_global_alloc::CustomGlobalAllocator;

mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */
// This is the main entry point for our Rust library

// Export the api module, which contains our exposed functions
pub mod api;
mod custom_global_alloc;

// We can also define utility functions or other modules here if needed
// mod utils;
// #[global_allocator]
static ALLOC: CustomGlobalAllocator =
    CustomGlobalAllocator::new(
            System
   );
