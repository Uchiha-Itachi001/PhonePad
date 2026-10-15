//! Shared runtime host state for GUI visualization and telemetry.

use std::sync::atomic::{AtomicBool, AtomicU32, AtomicU64, Ordering};
use std::sync::Mutex;
use std::time::Instant;

/// Thread-safe host state accessed by background listeners and the desktop GUI window.
pub struct HostState {
    pub is_connected: AtomicBool,
    pub is_active_session: AtomicBool,
    pub is_service_enabled: AtomicBool,
    pub auth_pin: u32,
    pub client_name: Mutex<String>,
    pub client_transport: Mutex<String>,
    pub packets_total: AtomicU64,
    pub packets_per_sec: AtomicU32,
    pub last_delta_x: Mutex<f32>,
    pub last_delta_y: Mutex<f32>,
    pub sensitivity: Mutex<f32>,
    pub natural_scroll: AtomicBool,
    pub gestures_enabled: AtomicBool,
    pub tap_to_click: AtomicBool,
    pub local_ip: Mutex<String>,
    pub port: u16,
    pub computer_name: String,
    last_second_time: Mutex<Instant>,
    second_packet_counter: AtomicU32,
}

impl HostState {
    pub fn new(local_ip: String, port: u16, computer_name: String, auth_pin: u32) -> Self {
        Self {
            is_connected: AtomicBool::new(false),
            is_active_session: AtomicBool::new(false),
            is_service_enabled: AtomicBool::new(true),
            auth_pin,
            client_name: Mutex::new("Waiting for connection...".to_string()),
            client_transport: Mutex::new("None".to_string()),
            packets_total: AtomicU64::new(0),
            packets_per_sec: AtomicU32::new(0),
            last_delta_x: Mutex::new(0.0),
            last_delta_y: Mutex::new(0.0),
            sensitivity: Mutex::new(1.25),
            natural_scroll: AtomicBool::new(true),
            gestures_enabled: AtomicBool::new(true),
            tap_to_click: AtomicBool::new(true),
            local_ip: Mutex::new(local_ip),
            port,
            computer_name,
            last_second_time: Mutex::new(Instant::now()),
            second_packet_counter: AtomicU32::new(0),
        }
    }

    /// Tries to acquire exclusive session lock. Returns true if acquired.
    pub fn try_lock_session(&self) -> bool {
        self.is_active_session.compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst).is_ok()
    }

    /// Releases exclusive session lock.
    pub fn unlock_session(&self) {
        self.is_active_session.store(false, Ordering::SeqCst);
    }

    /// Records client connected
    pub fn set_connected(&self, client: &str, transport: &str) {
        self.is_connected.store(true, Ordering::SeqCst);
        if let Ok(mut name) = self.client_name.lock() {
            *name = client.to_string();
        }
        if let Ok(mut t) = self.client_transport.lock() {
            *t = transport.to_string();
        }
    }

    /// Records client disconnected
    pub fn set_disconnected(&self) {
        self.is_connected.store(false, Ordering::SeqCst);
        if let Ok(mut name) = self.client_name.lock() {
            *name = "Waiting for connection...".to_string();
        }
        if let Ok(mut t) = self.client_transport.lock() {
            *t = "None".to_string();
        }
        self.packets_per_sec.store(0, Ordering::Relaxed);
    }

    /// Records an incoming packet and updates rate metrics without mutex contention
    pub fn record_packet(&self, _dx: f32, _dy: f32) {
        self.packets_total.fetch_add(1, Ordering::Relaxed);
        let count = self.second_packet_counter.fetch_add(1, Ordering::Relaxed);

        // Check if 1 second elapsed to update PPS (sampled every 32 packets to avoid mutex lock thrashing)
        if count & 31 == 0 {
            if let Ok(mut last_time) = self.last_second_time.try_lock() {
                let elapsed = last_time.elapsed();
                if elapsed.as_millis() >= 1000 {
                    let pps = self.second_packet_counter.swap(0, Ordering::Relaxed);
                    self.packets_per_sec.store(pps, Ordering::Relaxed);
                    *last_time = Instant::now();
                }
            }
        }
    }
}
