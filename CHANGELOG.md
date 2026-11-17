# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-11-17

### Added

- Checked-in bindgen 0.72.1 bindings for the GLFW 3.5.1 header: 120 functions
  and 333 constants from `glfw3.h`, so consumers need neither `bindgen` nor
  `libclang`.
- Dynamic linking against the system GLFW library (`glfw` on Unix, `glfw3dll`
  on Windows), with `GLFW_STATIC` and `GLFW_LIB_DIR` build overrides and
  `links = "glfw"` metadata.
- Nullable callback and proc typedefs (`Option<unsafe extern "C" fn(...)>`),
  opaque `GLFWwindow`/`GLFWmonitor`/`GLFWcursor` handles, and verbatim
  constants.
- Smoke tests covering dynamic linkage, the linked runtime version, and the
  callback typedef shape.
- Release branches, signed tags, verification, publishing, and rollback
  scripts and documentation.

### Changed

- Edition 2024, minimum Rust 1.85.
- The crate is `MIT AND Zlib`: `src/bindings.rs` derives from GLFW's
  zlib-licensed header and retains its notice.

### Notes

- Only `glfw3.h` is bound; `glfw3native.h` and the Vulkan surface helpers are
  intentionally absent.
