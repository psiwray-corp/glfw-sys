# glfw-sys

Raw FFI bindings for [GLFW](https://www.glfw.org/), generated once with
[bindgen](https://rust-lang.github.io/rust-bindgen/) from the GLFW 3.5.1 header
and committed. The crate links the system GLFW library; it does not build or
vendor GLFW, and consumers do not need `bindgen` or `libclang`.

- 120 functions and 333 constants from `glfw3.h`.
- Direct `extern "C"` calls; no loader and no function-pointer table.
- Callback and proc typedefs are `Option<unsafe extern "C" fn(...)>`.
- `GLFWwindow`, `GLFWmonitor`, and `GLFWcursor` are opaque zero-sized types.
- `links = "glfw"`: only one crate in a dependency graph may link GLFW.

Rust 1.85+ (edition 2024).

## Requirements

A GLFW shared library at least as new as the bound header (3.5.1) on the
library search path.

| Platform | Install |
|---|---|
| Arch | `pacman -S glfw` |
| Debian/Ubuntu | `apt install libglfw3 libglfw3-dev` |
| Fedora | `dnf install glfw-devel` |
| macOS | `brew install glfw` |
| Windows | Official binaries; link the `glfw3dll` import library |

The headers are not needed at build time. On Windows keep `glfw3.dll` next to
the executable; on Unix make sure `libglfw.so.3`/`libglfw.dylib` is findable.

## Usage

```toml
[dependencies]
glfw-sys = { path = "../glfw-sys" }
```

```rust
unsafe {
    if glfw_sys::glfwInit() == 0 {
        panic!("GLFW initialization failed");
    }

    // ... create a window and context, then load OpenGL through GLFW ...

    glfw_sys::glfwTerminate();
}
```

All calls are `unsafe`: GLFW requires initialization and, on most platforms,
window and event calls on the main thread.

GLFW's proc-address function matches the loader signature used by glad-style
bindings:

```rust
let version = unsafe { glad::gladLoadGLGlfw(glfw_sys::glfwGetProcAddress) };
```

`glfwGetProcAddress` is a plain `extern "C" fn(*const c_char) ->
Option<unsafe extern "C" fn()>`, so it also coerces to any loader that accepts
that shape.

## Build configuration

| Variable | Effect |
|---|---|
| `GLFW_LIB_DIR` | Adds a native library search path (Homebrew, custom prefix) |
| `GLFW_STATIC` | Links `glfw`/`glfw3` statically instead of the DLL/shared library |

Static linking pulls in GLFW's own platform dependencies (X11, Wayland,
frameworks, and so on); providing them is the caller's responsibility.

## Scope

Only `glfw3.h` is bound. `glfw3native.h` is intentionally excluded, as are the
Vulkan surface helpers (`glfwCreateWindowSurface`,
`glfwGetInstanceProcAddress`, `glfwGetPhysicalDevicePresentationSupport`,
`glfwInitVulkanLoader`), which the header guards behind `VK_VERSION_1_0`. Pair
this crate with Vulkan bindings if you need those functions.

The smoke test asserts that the linked runtime is not older than the bound
header (3.5.1). To target an older GLFW, regenerate the bindings from that
version.

## Regenerating

Maintainers only; requires `bindgen-cli` and `libclang`:

```sh
bindgen /usr/include/GLFW/glfw3.h \
  --allowlist-function 'glfw.*' \
  --allowlist-type 'GLFW.*' \
  --allowlist-var 'GLFW_.*' \
  --no-layout-tests --no-prepend-enum-name \
  -o src/bindings.rs -- -DGLFW_INCLUDE_NONE
```

Then restore the GLFW notice at the top of `src/bindings.rs` (copy it from
`LICENSE-ZLIB`); bindgen does not carry the header's license comment over.

## License

Crate code is MIT (`LICENSE`). `src/bindings.rs` is derived from GLFW's
zlib-licensed header, retains its copyright notice, and is distributed under
the zlib license (`LICENSE-ZLIB`). The crate as a whole is `MIT AND Zlib`.

GLFW itself is not distributed by this crate; linking it is governed by its own
zlib license.

## Releases

Branch, tag, and publishing procedures are in
[docs/release/runbook.md](docs/release/runbook.md). Releases are signed locally
and published to the Forgejo registry.
