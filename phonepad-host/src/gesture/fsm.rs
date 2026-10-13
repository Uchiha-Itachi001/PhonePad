//! Finite State Machine (FSM) for advanced multi-touch gestures & drag-lock.

use crate::input::{InputInjector, MouseButton};
use crate::protocol::Packet;
use std::time::{Duration, Instant};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FsmState {
    Idle,
    SingleTouch,
    DragLock,
    Scrolling,
    ThreeFingerSwipe,
}

#[derive(Debug, Clone)]
pub struct FsmConfig {
    /// Displacement magnitude required to trigger a 3-finger swipe (raw units)
    pub swipe_threshold: i32,
    /// Cooldown window after a 3-finger swipe fires before another can trigger
    pub swipe_cooldown: Duration,
    /// Maximum time gap between tap release and subsequent touch down to engage drag lock
    pub drag_lock_window: Duration,
    /// Grace period after finger lift before releasing left mouse down during drag lock
    pub drag_lock_release_grace: Duration,
}

impl Default for FsmConfig {
    fn default() -> Self {
        Self {
            swipe_threshold: 24,
            swipe_cooldown: Duration::from_millis(400),
            drag_lock_window: Duration::from_millis(250),
            drag_lock_release_grace: Duration::from_millis(250),
        }
    }
}

pub struct GestureFsm {
    pub config: FsmConfig,
    state: FsmState,
    alt_tab_active: bool,
    last_single_tap_lift: Option<Instant>,
    last_drag_lift: Option<Instant>,
    last_swipe_time: Option<Instant>,
    swipe_accum_x: i32,
    swipe_accum_y: i32,
}

impl Default for GestureFsm {
    fn default() -> Self {
        Self::new(FsmConfig::default())
    }
}

impl GestureFsm {
    pub fn new(config: FsmConfig) -> Self {
        Self {
            config,
            state: FsmState::Idle,
            alt_tab_active: false,
            last_single_tap_lift: None,
            last_drag_lift: None,
            last_swipe_time: None,
            swipe_accum_x: 0,
            swipe_accum_y: 0,
        }
    }

    pub fn state(&self) -> FsmState {
        self.state
    }

    /// Evaluates incoming packets and dispatches gestures to injector if recognized.
    /// Returns true if the packet was fully consumed by FSM (e.g. 3-finger swipe).
    pub fn process_packet<I: InputInjector>(&mut self, packet: &Packet, injector: &mut I) -> bool {
        let now = Instant::now();
        let fingers = packet.finger_count();
        let touch_active = packet.is_touch_active();

        // Release active Alt+Tab switcher if fingers lift or finger count drops
        if self.alt_tab_active && (!touch_active || fingers < 3) {
            log::info!("3-Finger Lift -> Releasing Alt (Switch to selected app)");
            injector.alt_tab_finish();
            self.alt_tab_active = false;
        }

        // Handle 3-Finger System Swipes
        if fingers >= 3 && touch_active {
            if self.state == FsmState::DragLock {
                injector.mouse_up(MouseButton::Left);
            }
            self.state = FsmState::ThreeFingerSwipe;
            self.swipe_accum_x += packet.dx as i32;
            self.swipe_accum_y += packet.dy as i32;

            let in_cooldown = self
                .last_swipe_time
                .map(|t| now.duration_since(t) < self.config.swipe_cooldown)
                .unwrap_or(false);

            if !in_cooldown {
                let abs_x = self.swipe_accum_x.abs();
                let abs_y = self.swipe_accum_y.abs();

                if abs_x >= self.config.swipe_threshold || abs_y >= self.config.swipe_threshold {
                    if abs_x > abs_y {
                        let forward = self.swipe_accum_x > 0;
                        if !self.alt_tab_active {
                            log::info!("3-Finger Swipe -> Alt+Tab Start (Laptop Switcher)");
                            injector.alt_tab_start(forward);
                            self.alt_tab_active = true;
                        } else {
                            log::info!("3-Finger Swipe -> Alt+Tab Step");
                            injector.alt_tab_step(forward);
                        }
                    } else {
                        if self.alt_tab_active {
                            injector.alt_tab_finish();
                            self.alt_tab_active = false;
                        }
                        if self.swipe_accum_y < 0 {
                            log::info!("3-Finger Swipe Up -> Task View");
                            injector.show_task_view();
                        } else {
                            log::info!("3-Finger Swipe Down -> Show Desktop");
                            injector.show_desktop();
                        }
                    }

                    self.last_swipe_time = Some(now);
                    self.swipe_accum_x = 0;
                    self.swipe_accum_y = 0;
                }
            }
            return true; // 3-finger packets are consumed by gesture FSM
        } else if self.state == FsmState::ThreeFingerSwipe && !touch_active {
            self.state = FsmState::Idle;
            self.swipe_accum_x = 0;
            self.swipe_accum_y = 0;
            return true;
        }

        // Release any drag lock if multi-finger gesture begins (e.g. 2-finger scroll)
        if fingers > 1 && self.state == FsmState::DragLock {
            log::debug!("Multi-finger detected while in DragLock -> releasing Left Mouse");
            injector.mouse_up(MouseButton::Left);
            self.state = FsmState::Idle;
        }

        // Opcode TapLeft explicitly establishes tap timestamp for subsequent double-tap-to-drag
        if packet.opcode == crate::protocol::Opcode::TapLeft {
            self.last_single_tap_lift = Some(now);
            return false;
        }

        // Handle Tap-and-Hold Drag Lock transitions
        if fingers == 1 && touch_active {
            if self.state == FsmState::Idle {
                // Drag lock is ONLY permitted if an explicit tap occurred right before this touch down
                if let Some(tap_lift) = self.last_single_tap_lift {
                    if now.duration_since(tap_lift) <= self.config.drag_lock_window {
                        log::info!("Double tap hold detected -> Drag Lock engaged");
                        injector.mouse_down(MouseButton::Left);
                        self.state = FsmState::DragLock;
                        self.last_single_tap_lift = None;
                    } else {
                        self.state = FsmState::SingleTouch;
                        self.last_single_tap_lift = None;
                    }
                } else {
                    self.state = FsmState::SingleTouch;
                }
            }
        } else if !touch_active {
            // CRITICAL FIX: The instant finger lifts, immediately release mouse down.
            // Never leave mouse_down active on Windows!
            if self.state == FsmState::DragLock {
                log::debug!("Touch ended -> releasing Left Mouse button");
                injector.mouse_up(MouseButton::Left);
                self.state = FsmState::Idle;
                self.last_drag_lift = None;
            } else {
                self.state = FsmState::Idle;
            }
        }

        false
    }

    /// Records that a genuine TapLeft click was executed (enabling subsequent drag lock window)
    pub fn record_tap(&mut self) {
        self.last_single_tap_lift = Some(Instant::now());
    }

    /// Explicitly forces drag lock mode (e.g. from Opcode::DragStart)
    pub fn force_drag_lock(&mut self) {
        self.state = FsmState::DragLock;
        self.last_drag_lift = None;
    }

    /// Explicitly resets FSM state and ensures held mouse buttons are cleared.
    pub fn reset<I: InputInjector>(&mut self, injector: &mut I) {
        if self.alt_tab_active {
            injector.alt_tab_finish();
            self.alt_tab_active = false;
        }
        if self.state == FsmState::DragLock {
            injector.mouse_up(MouseButton::Left);
        }
        self.state = FsmState::Idle;
        self.last_single_tap_lift = None;
        self.last_drag_lift = None;
        self.swipe_accum_x = 0;
        self.swipe_accum_y = 0;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::input::DummyInjector;
    use crate::protocol::Opcode;

    #[test]
    fn test_three_finger_swipe_up_triggers_task_view() {
        let mut fsm = GestureFsm::default();
        let mut dummy = DummyInjector::new();

        // 3 fingers down with upward delta (negative dy)
        let p1 = Packet::new(Opcode::Move, 0, -30, 0x01 | (3 << 1));
        let consumed = fsm.process_packet(&p1, &mut dummy);

        assert!(consumed);
        assert_eq!(dummy.task_view_count, 1);
    }

    #[test]
    fn test_three_finger_swipe_down_triggers_show_desktop() {
        let mut fsm = GestureFsm::default();
        let mut dummy = DummyInjector::new();

        // 3 fingers down with downward delta (positive dy)
        let p1 = Packet::new(Opcode::Move, 0, 30, 0x01 | (3 << 1));
        let consumed = fsm.process_packet(&p1, &mut dummy);

        assert!(consumed);
        assert_eq!(dummy.show_desktop_count, 1);
    }

    #[test]
    fn test_three_finger_swipe_horizontal_triggers_app_switch() {
        let mut fsm = GestureFsm::default();
        let mut dummy = DummyInjector::new();

        // Swipe right (Alt + Tab)
        let p_right = Packet::new(Opcode::Move, 35, 0, 0x01 | (3 << 1));
        assert!(fsm.process_packet(&p_right, &mut dummy));
        assert_eq!(dummy.app_switch_next_count, 1);
    }

    #[test]
    fn test_tap_and_hold_engages_drag_lock() {
        let mut fsm = GestureFsm::default();
        let mut dummy = DummyInjector::new();

        // First tap: genuine TapLeft event
        let p_tap = Packet::new(Opcode::TapLeft, 0, 0, 0x01 | (1 << 1));
        fsm.process_packet(&p_tap, &mut dummy);

        // Second tap down within 250ms -> drag lock engages!
        let p_down2 = Packet::new(Opcode::Move, 10, 5, 0x01 | (1 << 1));
        fsm.process_packet(&p_down2, &mut dummy);

        assert_eq!(fsm.state(), FsmState::DragLock);
        assert_eq!(dummy.mouse_down_count, 1);

        // Finger lift immediately clears drag lock
        let p_up = Packet::new(Opcode::Move, 0, 0, 0x00);
        fsm.process_packet(&p_up, &mut dummy);

        assert_eq!(fsm.state(), FsmState::Idle);
        assert_eq!(dummy.mouse_up_count, 1);

        // Reset clears left button
        fsm.reset(&mut dummy);
        assert_eq!(fsm.state(), FsmState::Idle);
    }
}
