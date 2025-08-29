#![feature(optimize_attribute)]
#![feature(allocator_api)]
#![feature(alloc_layout_extra)]


use std::alloc::{GlobalAlloc, System};
use crate::custom_global_alloc::CustomGlobalAllocator;

pub mod api;
mod frb_generated;
mod custom_global_alloc;

// We can also define utility functions or other modules here if needed
// mod utils;
#[global_allocator]
static ALLOC: CustomGlobalAllocator =
    CustomGlobalAllocator::new(
            System
   );
