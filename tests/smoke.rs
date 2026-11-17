use std::ffi::CStr;

// Compile-time proof of the `-sys` shape: GLFW proc/callback typedefs are
// nullable, so consumers can pass `None` without inventing fake pointers.
const _: glfw_sys::GLFWkeyfun = None;
const _: glfw_sys::GLFWglproc = None;

#[test]
fn links_against_system_glfw_and_reports_its_version() {
    let (mut major, mut minor, mut revision) = (0, 0, 0);
    unsafe {
        glfw_sys::glfwGetVersion(&mut major, &mut minor, &mut revision);
    }

    let version = unsafe { CStr::from_ptr(glfw_sys::glfwGetVersionString()) };
    assert!(
        version.to_string_lossy().starts_with("3."),
        "unexpected GLFW version string: {:?}",
        version
    );

    // The runtime library must be at least as new as the bound header, or the
    // generated declarations could reference symbols that do not exist.
    assert_eq!(major as u32, glfw_sys::GLFW_VERSION_MAJOR);
    assert!(
        (minor as u32, revision as u32)
            >= (
                glfw_sys::GLFW_VERSION_MINOR,
                glfw_sys::GLFW_VERSION_REVISION
            ),
        "linked GLFW {major}.{minor}.{revision} is older than the bound header"
    );
}

#[test]
fn constants_are_bound() {
    assert_eq!(glfw_sys::GLFW_TRUE, 1);
    assert_eq!(glfw_sys::GLFW_PRESS, 1);
}
