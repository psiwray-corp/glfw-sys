use std::env;

fn main() {
    println!("cargo:rerun-if-changed=build.rs");
    println!("cargo:rerun-if-env-changed=GLFW_LIB_DIR");
    println!("cargo:rerun-if-env-changed=GLFW_STATIC");

    if let Some(dir) = env::var_os("GLFW_LIB_DIR") {
        println!("cargo:rustc-link-search=native={}", dir.to_string_lossy());
    }

    let target_os = env::var("CARGO_CFG_TARGET_OS").unwrap_or_default();
    let static_link = env::var_os("GLFW_STATIC").is_some();

    // GLFW ships `glfw3dll.lib` (import library) alongside the DLL on Windows;
    // `glfw3.lib` is the static library. Elsewhere both are spelled `glfw`.
    let lib = if target_os == "windows" && !static_link {
        "glfw3dll"
    } else if target_os == "windows" {
        "glfw3"
    } else {
        "glfw"
    };

    let kind = if static_link && target_os != "windows" {
        "static"
    } else {
        "dylib"
    };
    println!("cargo:rustc-link-lib={kind}={lib}");
}
