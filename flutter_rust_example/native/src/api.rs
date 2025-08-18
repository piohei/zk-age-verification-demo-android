// This is the Rust API that will be exposed to Dart through flutter_rust_bridge

/// Returns a greeting message from Rust
pub fn hello_world() -> String {
    "Hello World!".to_string()
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
