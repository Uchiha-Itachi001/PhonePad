//! Connection session processor for PhonePad byte streams.

use crate::companion::CompanionTelemetry;
use crate::gesture::{BallisticsEngine, FsmState, GestureFilter, GestureFsm};
use crate::input::InputInjector;
use crate::protocol::{Opcode, Packet, PACKET_SIZE};
use super::state::HostState;
use std::sync::Arc;
use std::time::Duration;
use tokio::io::{AsyncRead, AsyncReadExt};
use tokio::time::timeout;

/// Processes an active PhonePad streaming session.
pub struct SessionHandler<I: InputInjector> {
    pub injector: I,
    pub ballistics: BallisticsEngine,
    pub filter: GestureFilter,
    pub fsm: GestureFsm,
    pub telemetry: CompanionTelemetry,
    pub packets_received: u64,
    pub state: Option<Arc<HostState>>,
}

impl<I: InputInjector> SessionHandler<I> {
    pub fn new(
        injector: I,
        ballistics: BallisticsEngine,
        filter: GestureFilter,
        fsm: GestureFsm,
    ) -> Self {
        Self {
            injector,
            ballistics,
            filter,
            fsm,
            telemetry: CompanionTelemetry::default(),
            packets_received: 0,
            state: None,
        }
    }

    pub fn with_state(mut self, state: Arc<HostState>) -> Self {
        self.state = Some(state);
        self
    }

    /// Dispatches a single parsed packet to the input pipeline.
    pub fn handle_packet(&mut self, mut packet: Packet) {
        // Defensive bounding: clamp deltas to prevent integer overflow or erratic input injection
        match packet.opcode {
            Opcode::Move | Opcode::DragStart => {
                packet.dx = packet.dx.clamp(-2048, 2048);
                packet.dy = packet.dy.clamp(-2048, 2048);
            }
            Opcode::Scroll => {
                if packet.flags & crate::protocol::FLAG_DISCRETE_NOTCH != 0 {
                    packet.dx = packet.dx.clamp(-20, 20);
                    packet.dy = packet.dy.clamp(-20, 20);
                } else {
                    packet.dx = packet.dx.clamp(-2048, 2048);
                    packet.dy = packet.dy.clamp(-2048, 2048);
                }
            }
            Opcode::Zoom => {
                packet.dx = packet.dx.clamp(-20, 20);
                packet.dy = packet.dy.clamp(-50, 50);
            }
            _ => {}
        }

        self.packets_received += 1;
        self.telemetry.record_packet(packet.flags);

        if let Some(ref s) = self.state {
            s.record_packet(packet.dx as f32, packet.dy as f32);

            // Drop input if user paused/stopped service in desktop app
            if !s.is_service_enabled.load(std::sync::atomic::Ordering::Relaxed) {
                return;
            }

            // Sync dynamic sensitivity and natural scroll from host state
            if let Ok(sens) = s.sensitivity.lock() {
                self.ballistics.set_sensitivity(*sens);
            }
            let natural = s.natural_scroll.load(std::sync::atomic::Ordering::Relaxed);
            self.filter.set_natural_scroll(natural);
        }

        // Give the Gesture FSM first priority (3-finger swipes, drag-lock)
        if self.fsm.process_packet(&packet, &mut self.injector) {
            return;
        }

        if packet.opcode != Opcode::Zoom {
            self.injector.zoom_finish();
        }

        match packet.opcode {
            Opcode::Move => {
                let (fx, fy) = if packet.flags & crate::protocol::FLAG_HIGH_RES != 0 {
                    (packet.dx as f32 / 8.0, packet.dy as f32 / 8.0)
                } else {
                    (packet.dx as f32, packet.dy as f32)
                };
                let (filtered_dx, filtered_dy) = self.filter.apply_deadzone_f32(fx, fy);
                let (move_x, move_y) = self.ballistics.process_delta_f32(filtered_dx, filtered_dy);
                self.injector.move_relative(move_x, move_y);
            }
            Opcode::TapLeft => {
                log::debug!("Left click trigger");
                self.fsm.record_tap();
                self.injector.click_left();
                self.ballistics.reset_accumulator();
            }
            Opcode::TapRight => {
                log::debug!("Right click trigger");
                self.fsm.reset(&mut self.injector);
                self.injector.click_right();
                self.ballistics.reset_accumulator();
            }
            Opcode::MiddleClick => {
                log::debug!("Middle click trigger");
                self.fsm.reset(&mut self.injector);
                self.injector.click_middle();
                self.ballistics.reset_accumulator();
            }
            Opcode::Scroll => {
                // If not actively holding a drag lock, reset FSM gestures
                if self.fsm.state() != FsmState::DragLock {
                    self.fsm.reset(&mut self.injector);
                }
                if packet.flags & crate::protocol::FLAG_DISCRETE_NOTCH != 0 {
                    // Discrete notch scrolling (e.g. remote scroll rocker, reels navigation)
                    // packet.dy is exact notch count (+1 = 1 notch up / -1 = 1 notch down)
                    self.injector.scroll(packet.dx as i32, packet.dy as i32);
                } else {
                    let (fx, fy) = if packet.flags & crate::protocol::FLAG_HIGH_RES != 0 {
                        (packet.dx as f32 / 8.0, packet.dy as f32 / 8.0)
                    } else {
                        (packet.dx as f32, packet.dy as f32)
                    };
                    let (wheel_x, wheel_y) = self.filter.process_smooth_scroll(fx, fy);
                    if wheel_x != 0 || wheel_y != 0 {
                        self.injector.scroll_raw(wheel_x, wheel_y);
                    }
                }
            }
            Opcode::DragStart => {
                log::debug!("Drag start trigger (Left mouse button down)");
                self.fsm.force_drag_lock();
                self.injector.mouse_down(crate::input::MouseButton::Left);
                if packet.dx != 0 || packet.dy != 0 {
                    let (fx, fy) = if packet.flags & crate::protocol::FLAG_HIGH_RES != 0 {
                        (packet.dx as f32 / 8.0, packet.dy as f32 / 8.0)
                    } else {
                        (packet.dx as f32, packet.dy as f32)
                    };
                    let (filtered_dx, filtered_dy) = self.filter.apply_deadzone_f32(fx, fy);
                    let (move_x, move_y) = self.ballistics.process_delta_f32(filtered_dx, filtered_dy);
                    self.injector.move_relative(move_x, move_y);
                }
            }
            Opcode::DragEnd => {
                log::debug!("Drag end trigger (Left mouse button up)");
                self.fsm.reset(&mut self.injector);
            }
            Opcode::Zoom => {
                log::debug!("Zoom trigger (Pinch): delta={}", packet.dy);
                if packet.dy == 0 {
                    self.injector.zoom_finish();
                } else {
                    self.injector.zoom(packet.dy as i32);
                }
            }
            Opcode::Heartbeat => {
                log::trace!("Heartbeat received (Flags: {:08b})", packet.flags);
            }
            Opcode::Ack => {
                log::trace!("Ping/Ack probe received");
            }
            Opcode::SleepStandby => {
                log::info!("Device requested Sleep/Standby mode");
            }
            Opcode::Numpad => {
                let key = crate::input::NumpadKey::from(packet.dx);
                self.injector.send_numpad_key(key);
            }
            Opcode::Media => {
                let key = crate::input::MediaKey::from(packet.dx);
                self.injector.send_media_key(key);
            }
            Opcode::Keyboard => {
                let event_type = packet.dy as u8;
                let code = packet.dx as u16;
                self.injector.send_keyboard_event(event_type, code);
            }
            Opcode::Unknown(op) => {
                log::warn!("Ignored unknown packet opcode: 0x{:02X}", op);
            }
        }

        // If touch is no longer active, reset sub-pixel accumulator and finish zoom
        if !packet.is_touch_active() {
            if packet.opcode == Opcode::Move {
                self.ballistics.reset_accumulator();
                self.filter.reset();
            }
            self.injector.zoom_finish();
        }
    }

    /// Asynchronously consumes 6-byte frames from a stream until disconnect or watchdog timeout.
    pub async fn run_stream<R>(&mut self, stream: R, idle_timeout: Duration) -> Result<(), Box<dyn std::error::Error + Send + Sync>>
    where
        R: AsyncRead + Unpin,
    {
        let mut reader = tokio::io::BufReader::with_capacity(1024, stream);
        let mut buf = [0u8; PACKET_SIZE];
        let mut first_frame = true;
        let mut packet_window_start = std::time::Instant::now();
        let mut packet_window_count = 0u32;

        let handshake_timeout = Duration::from_secs(3);
        loop {
            // Handshake deadline (3s) on initial frame; standard idle watchdog timeout thereafter
            let active_timeout = if first_frame { handshake_timeout } else { idle_timeout };

            match timeout(active_timeout, reader.read_exact(&mut buf)).await {
                Ok(Ok(_)) => {
                    if first_frame {
                        if buf[0] != crate::protocol::HANDSHAKE_MAGIC {
                            log::warn!("🚨 SECURITY: Connection rejected - First frame was not a valid PhonePad handshake (magic: 0x{:02X})", buf[0]);
                            break;
                        }
                        first_frame = false;
                        let mut extra = [0u8; 6];
                        if let Err(e) = reader.read_exact(&mut extra).await {
                            log::warn!("Failed reading handshake extra bytes: {}", e);
                            break;
                        }
                        let mut handshake_buf = [0u8; crate::protocol::HANDSHAKE_SIZE];
                        handshake_buf[..6].copy_from_slice(&buf);
                        handshake_buf[6..12].copy_from_slice(&extra);
                        match crate::protocol::HandshakeFrame::from_bytes(&handshake_buf) {
                            Ok(hs) => {
                                log::info!(
                                    "✨ Client handshake verified: device_id=0x{:08X}, type={:?}",
                                    hs.device_id,
                                    hs.device_type
                                );
                                if let Some(ref s) = self.state {
                                    let device_name = match hs.device_type {
                                        crate::protocol::DeviceType::Phone => "PhonePad Mobile",
                                        crate::protocol::DeviceType::Tablet => "PhonePad Tablet",
                                        _ => "PhonePad Client",
                                    };
                                    s.set_connected(device_name, "Wi-Fi (TCP)");
                                }
                            }
                            Err(e) => {
                                log::warn!("Security violation: Handshake rejected ({}) - closing session.", e);
                                break;
                            }
                        }
                        continue;
                    }

                    // Rate limit: protect against DoS input flooding (>4000 packets/sec)
                    packet_window_count += 1;
                    if packet_window_count > 400 {
                        let elapsed = packet_window_start.elapsed();
                        if elapsed.as_millis() < 100 {
                            continue; // Drop flood packet
                        } else {
                            packet_window_start = std::time::Instant::now();
                            packet_window_count = 0;
                        }
                    }

                    if let Some(ref s) = self.state {
                        if !s.is_connected.load(std::sync::atomic::Ordering::Relaxed) {
                            s.set_connected("Mobile Phone", "Wi-Fi (TCP)");
                        }
                    }
                    first_frame = false;
                    let packet = Packet::from_bytes(&buf);
                    self.handle_packet(packet);
                }
                Ok(Err(e)) => {
                    log::info!("Stream closed or read error: {}", e);
                    break;
                }
                Err(_) => {
                    log::warn!("Watchdog timeout: No packets received for {:?}", idle_timeout);
                    break;
                }
            }
        }

        if let Some(ref s) = self.state {
            s.set_disconnected();
        }

        // Safety: Clear any held mouse buttons or drag locks
        self.fsm.reset(&mut self.injector);
        self.injector.mouse_up(crate::input::MouseButton::Left);

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::gesture::GestureFsm;
    use crate::input::DummyInjector;

    #[tokio::test]
    async fn test_session_handler_stream() {
        let dummy = DummyInjector::new();
        let ballistics = BallisticsEngine::default();
        let filter = GestureFilter::default();
        let fsm = GestureFsm::default();

        let mut session = SessionHandler::new(dummy, ballistics, filter, fsm);

        // Prepare mock stream with initial valid handshake followed by 3 touch packets
        let hs = crate::protocol::HandshakeFrame::new(0x12345678, crate::protocol::DeviceType::Phone, 0);
        let p1 = Packet::new(Opcode::Move, 10, 5, 0x01);
        let p2 = Packet::new(Opcode::TapLeft, 0, 0, 0x01);
        let p3 = Packet::new(Opcode::TapRight, 0, 0, 0x02);

        let mut stream_bytes = Vec::new();
        stream_bytes.extend_from_slice(&hs.to_bytes());
        stream_bytes.extend_from_slice(&p1.to_bytes());
        stream_bytes.extend_from_slice(&p2.to_bytes());
        stream_bytes.extend_from_slice(&p3.to_bytes());

        let reader = &stream_bytes[..];
        session.run_stream(reader, Duration::from_millis(500)).await.unwrap();

        assert_eq!(session.packets_received, 3);
        assert_eq!(session.injector.left_clicks, 1);
        assert_eq!(session.injector.right_clicks, 1);
        assert!(session.injector.moved_x > 0);
    }

    #[tokio::test]
    async fn test_session_handler_numpad_and_media_packets() {
        let dummy = DummyInjector::new();
        let ballistics = BallisticsEngine::default();
        let filter = GestureFilter::default();
        let fsm = GestureFsm::default();

        let mut session = SessionHandler::new(dummy, ballistics, filter, fsm);

        // Numpad 7 (dx = 7), Media PlayPause (dx = 1), and Keyboard 'A' (dx = 65, dy = 0)
        let p1 = Packet::new(Opcode::Numpad, 7, 0, 0x01);
        let p2 = Packet::new(Opcode::Media, 1, 0, 0x01);
        let p3 = Packet::new(Opcode::Keyboard, 65, 0, 0x01);

        session.handle_packet(p1);
        session.handle_packet(p2);
        session.handle_packet(p3);

        assert_eq!(session.injector.numpad_keys.len(), 1);
        assert_eq!(session.injector.numpad_keys[0], crate::input::NumpadKey::Num7);

        assert_eq!(session.injector.media_keys.len(), 1);
        assert_eq!(session.injector.media_keys[0], crate::input::MediaKey::PlayPause);

        assert_eq!(session.injector.keyboard_events.len(), 1);
        assert_eq!(session.injector.keyboard_events[0], (0, 65));
    }

    #[tokio::test]
    async fn test_session_handler_stream_with_initial_handshake() {
        let dummy = DummyInjector::new();
        let ballistics = BallisticsEngine::default();
        let filter = GestureFilter::default();
        let fsm = GestureFsm::default();

        let mut session = SessionHandler::new(dummy, ballistics, filter, fsm);

        let handshake = crate::protocol::HandshakeFrame::new(0x12345678, crate::protocol::DeviceType::Phone, 0);
        let p1 = Packet::new(Opcode::TapLeft, 0, 0, 0x01);

        let mut stream_bytes = Vec::new();
        stream_bytes.extend_from_slice(&handshake.to_bytes());
        stream_bytes.extend_from_slice(&p1.to_bytes());

        let reader = &stream_bytes[..];
        session.run_stream(reader, Duration::from_millis(500)).await.unwrap();

        assert_eq!(session.packets_received, 1);
        assert_eq!(session.injector.left_clicks, 1);
    }

    #[tokio::test]
    async fn test_session_handler_accepts_same_wifi_client() {
        let dummy = DummyInjector::new();
        let ballistics = BallisticsEngine::default();
        let filter = GestureFilter::default();
        let fsm = GestureFsm::default();

        let state = std::sync::Arc::new(crate::server::HostState::new("127.0.0.1".into(), 4242, "PC".into(), 0));
        let mut session = SessionHandler::new(dummy, ballistics, filter, fsm).with_state(state);

        // Same Wi-Fi client connects directly without PIN friction
        let hs = crate::protocol::HandshakeFrame::new(0xDEADBEEF, crate::protocol::DeviceType::Phone, 0);
        let p1 = Packet::new(Opcode::TapLeft, 0, 0, 0x01);

        let mut stream_bytes = Vec::new();
        stream_bytes.extend_from_slice(&hs.to_bytes());
        stream_bytes.extend_from_slice(&p1.to_bytes());

        let reader = &stream_bytes[..];
        session.run_stream(reader, Duration::from_millis(500)).await.unwrap();

        assert_eq!(session.packets_received, 1);
        assert_eq!(session.injector.left_clicks, 1);
    }

    #[tokio::test]
    async fn test_session_handler_accepts_valid_pin() {
        let dummy = DummyInjector::new();
        let ballistics = BallisticsEngine::default();
        let filter = GestureFilter::default();
        let fsm = GestureFsm::default();

        let state = std::sync::Arc::new(crate::server::HostState::new("127.0.0.1".into(), 4242, "PC".into(), 9999));
        let mut session = SessionHandler::new(dummy, ballistics, filter, fsm).with_state(state);

        // Authorized client with correct PIN 9999
        let valid_hs = crate::protocol::HandshakeFrame::new(0x12345678, crate::protocol::DeviceType::Phone, 9999);
        let p1 = Packet::new(Opcode::TapLeft, 0, 0, 0x01);

        let mut stream_bytes = Vec::new();
        stream_bytes.extend_from_slice(&valid_hs.to_bytes());
        stream_bytes.extend_from_slice(&p1.to_bytes());

        let reader = &stream_bytes[..];
        session.run_stream(reader, Duration::from_millis(500)).await.unwrap();

        // Successfully authorized
        assert_eq!(session.packets_received, 1);
        assert_eq!(session.injector.left_clicks, 1);
    }

    #[tokio::test]
    async fn test_session_handler_discrete_notch_scroll_and_zoom() {
        let dummy = DummyInjector::new();
        let ballistics = BallisticsEngine::default();
        let filter = GestureFilter::default();
        let fsm = GestureFsm::default();
        let mut session = SessionHandler::new(dummy, ballistics, filter, fsm);

        // 1. Discrete notch scroll down (1 notch = -120 units)
        let p_scroll = Packet::new(Opcode::Scroll, 0, -1, crate::protocol::FLAG_DISCRETE_NOTCH);
        session.handle_packet(p_scroll);
        assert_eq!(session.injector.scroll_raw_y, -120);

        // 2. Zoom in increment
        let p_zoom = Packet::new(Opcode::Zoom, 0, 1, 0x01);
        session.handle_packet(p_zoom);
        assert_eq!(session.injector.zoom_notches, 1);

        // 3. Zoom finish packet
        let p_zoom_finish = Packet::new(Opcode::Zoom, 0, 0, 0x00);
        session.handle_packet(p_zoom_finish);
        assert_eq!(session.injector.zoom_finished_count, 1);
    }
}

