#!/bin/bash
# Simplified script using configuration file

set -e # Exit on error

echo "=== Flutter Rust Bridge Builder ==="

# Install required tools if missing
command -v flutter_rust_bridge_codegen >/dev/null 2>&1 || {
  echo "Installing flutter_rust_bridge_codegen..."
  cargo install flutter_rust_bridge_codegen
}

echo "Ensuring Rust targets for Android are installed..."
rustup target add aarch64-linux-android
rustup target add armv7-linux-androideabi
rustup target add i686-linux-android
rustup target add x86_64-linux-android

echo "Generating bridge code using config file..."
# This will use the flutter_rust_bridge.yaml configuration file
flutter_rust_bridge_codegen generate

echo "Building Rust code for Android..."
cd native
cargo ndk -t aarch64-linux-android build --release
cargo ndk -t armv7-linux-androideabi build --release
cargo ndk -t i686-linux-android build --release
cargo ndk -t x86_64-linux-android build --release
cd ..

echo "Creating JNI directories..."
mkdir -p android/app/src/main/jniLibs/arm64-v8a
mkdir -p android/app/src/main/jniLibs/armeabi-v7a
mkdir -p android/app/src/main/jniLibs/x86
mkdir -p android/app/src/main/jniLibs/x86_64

echo "Copying libraries to JNI directories..."
cp native/target/aarch64-linux-android/release/libnative.so android/app/src/main/jniLibs/arm64-v8a/
cp native/target/armv7-linux-androideabi/release/libnative.so android/app/src/main/jniLibs/armeabi-v7a/
cp native/target/i686-linux-android/release/libnative.so android/app/src/main/jniLibs/x86/
cp native/target/x86_64-linux-android/release/libnative.so android/app/src/main/jniLibs/x86_64/

echo "=== Build completed successfully ==="
