//! Desktop UI Module for PhonePad Host.

pub mod window;

#[cfg(windows)]
pub use window::win32_window::run_desktop_window;
