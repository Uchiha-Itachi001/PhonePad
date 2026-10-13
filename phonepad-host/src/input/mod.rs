//! Input injection module.

pub mod dummy;
pub mod traits;

#[cfg(windows)]
pub mod windows;

pub use dummy::DummyInjector;
pub use traits::{InputInjector, MediaKey, MouseButton, NumpadKey, WHEEL_DELTA};

#[cfg(windows)]
pub use windows::WindowsInjector;

/// Returns the native platform injector.
pub fn create_default_injector() -> Box<dyn InputInjector> {
    #[cfg(windows)]
    {
        Box::new(WindowsInjector::new())
    }
    #[cfg(not(windows))]
    {
        log::info!("Using DummyInjector on non-Windows platform");
        Box::new(DummyInjector::new())
    }
}
