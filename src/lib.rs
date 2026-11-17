//! Raw FFI bindings for [GLFW](https://www.glfw.org/).
//!
//! The bindings are generated once with bindgen from the GLFW 3.5.1 header and
//! committed, so downstream builds need neither `bindgen` nor `libclang`. The
//! crate links the system GLFW library (`libglfw.so`/`libglfw.dylib`, or the
//! `glfw3dll` import library on Windows) and exposes the C API verbatim.
//!
//! Build-time overrides:
//!
//! - `GLFW_LIB_DIR=/path/to/lib`: add a native library search path, e.g. for
//!   Homebrew or a custom prefix.
//! - `GLFW_STATIC=1`: link the static library instead (`glfw` on Unix,
//!   `glfw3` on Windows). Transitive system dependencies of a static GLFW
//!   build are the caller's responsibility.
//!
//! Only `glfw3.h` is bound. `glfw3native.h` is intentionally not included, and
//! the Vulkan surface helpers (`glfwCreateWindowSurface`,
//! `glfwGetInstanceProcAddress`, `glfwGetPhysicalDevicePresentationSupport`,
//! `glfwInitVulkanLoader`) are absent because the header guards them behind
//! `VK_VERSION_1_0`. Include Vulkan bindings if you need them.
//!
//! Regenerate after updating the pinned header:
//!
//! ```text
//! bindgen /usr/include/GLFW/glfw3.h \
//!   --allowlist-function 'glfw.*' \
//!   --allowlist-type 'GLFW.*' \
//!   --allowlist-var 'GLFW_.*' \
//!   --no-layout-tests --no-prepend-enum-name \
//!   -o src/bindings.rs -- -DGLFW_INCLUDE_NONE
//! ```
//!
//! Regeneration drops the header comment; restore the GLFW notice at the top
//! of `src/bindings.rs` (copy it from `LICENSE-ZLIB`).
//!
//! ## Licensing
//!
//! This crate's own code (build script, tests, this file) is MIT-licensed, see
//! `LICENSE`. `src/bindings.rs` is derived from GLFW's zlib-licensed
//! `glfw3.h`, retains its copyright notice, and is distributed under the zlib
//! license, see `LICENSE-ZLIB`. `Cargo.toml` therefore declares
//! `MIT AND Zlib`.
//!
//! Every function is `unsafe`: callers must respect GLFW's initialization and
//! threading rules (most platforms require window and event calls on the main
//! thread).

#![allow(non_camel_case_types, non_snake_case, non_upper_case_globals)]
#![allow(clippy::all)]

include!("bindings.rs");
