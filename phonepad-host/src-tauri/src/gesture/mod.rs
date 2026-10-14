//! Gesture processing, acceleration, filtering, and FSM recognition.

pub mod ballistics;
pub mod filter;
pub mod fsm;

pub use ballistics::{BallisticsConfig, BallisticsEngine};
pub use filter::{FilterConfig, GestureFilter};
pub use fsm::{FsmConfig, FsmState, GestureFsm};
