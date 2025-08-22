use std::{
    alloc::{GlobalAlloc, Layout, System},
};
use std::fs::File;
use std::path::PathBuf;
use std::sync::Mutex;
use std::time::Duration;
use memmap2::{MmapMut, MmapOptions};
use tempfile::{env, tempfile, tempfile_in};
use log::info;

pub struct MemMap2File {
    file: File,
    pub mmap: MmapMut,
}

impl MemMap2File {
    pub fn new(tmp_dir_path: PathBuf, size: usize) -> Self {
        let file = tempfile_in(tmp_dir_path).expect("file created");
        file.set_len(size as u64).expect("file resized");

        let mmap = unsafe {
            MmapOptions::new()
                // .len(size)
                // .map_mut(&file)
                .map_copy(&file)
                // .map_raw(&file)
                .expect("mmap mut created")
        };

        Self {
            file,
            mmap,
        }
    }

    pub fn flush(&mut self) -> std::io::Result<()> {
        self.mmap.flush()?;

        let mmap = unsafe {
            MmapOptions::new()
                // .map_mut(&file)
                .map_copy(&self.file)
                // .map_raw(&file)
                .expect("mmap mut created")
        };

        self.mmap = mmap;

        Ok(())
    }
}

pub struct CustomGlobalAllocator {
    tmp_dir_path: Mutex<Vec<PathBuf>>,
    allocations: Mutex<Vec<MemMap2File>>,
    parent: System,
}

impl CustomGlobalAllocator {
    pub const fn new(parent: System) -> Self {
        Self {
            tmp_dir_path: Mutex::new(Vec::new()),
            allocations: Mutex::new(Vec::new()),
            parent,
        }
    }

    pub fn set_tmp_dir_path(&self, tmp_dir_path: String) {
        let mut val = self.tmp_dir_path.lock().unwrap();
        val.push(tmp_dir_path.into());
    }
}

const SIZE_16MB: usize = 16 * 1024 * 1024;

#[allow(unsafe_code)]
unsafe impl GlobalAlloc for CustomGlobalAllocator {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        if layout.size() > SIZE_16MB {
            info!("[zzz] Allocating using mmap (v2)");
            let mut allocations = self.allocations.lock().unwrap();
            let tmp_dir_path = self.tmp_dir_path.lock().unwrap().last().unwrap().clone();

            info!("[zzz] Allocating using mmap (v2) - create mmap - #1");
            let mut map = MemMap2File::new(tmp_dir_path, layout.size());
            let ptr = map.mmap.as_mut_ptr();
            allocations.push(map);

            info!("[zzz] Allocating using mmap (v2) - create mmap - #2");

            ptr
        } else {
            self.parent.alloc(layout)
        }
    }

    unsafe fn dealloc(&self, ptr: *mut u8, layout: Layout) {
        if layout.size() > SIZE_16MB {
            let mut allocations = self.allocations.lock().unwrap();

            for (pos, map) in allocations.iter().enumerate() {
                if map.mmap.as_ptr() == ptr {
                    allocations.remove(pos);
                    return;
                }
            }

            panic!("Could not find memory to deallocate.")
        } else {
            self.parent.dealloc(ptr, layout)
        }
    }
}
