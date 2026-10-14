//! UDP Auto-Discovery beacon for zero-configuration Wi-Fi connection.

use super::state::HostState;
use std::net::{SocketAddr, UdpSocket};
use std::sync::Arc;
use std::time::{Duration, Instant};

/// Returns the primary outbound local IPv4 address of the machine.
/// Uses multiple probe targets to succeed even on offline Wi-Fi, LANs, and mobile hotspots.
pub fn get_local_ip() -> String {
    let targets = [
        "8.8.8.8:80",
        "1.1.1.1:80",
        "192.168.1.1:80",
        "192.168.0.1:80",
        "192.168.137.1:80",
        "192.168.43.1:80",
        "10.0.0.1:80",
        "172.16.0.1:80",
    ];

    for target in &targets {
        if let Ok(socket) = UdpSocket::bind("0.0.0.0:0") {
            if socket.connect(target).is_ok() {
                if let Ok(addr) = socket.local_addr() {
                    let ip = addr.ip().to_string();
                    if ip != "127.0.0.1" && ip != "0.0.0.0" {
                        return ip;
                    }
                }
            }
        }
    }
    "127.0.0.1".to_string()
}

/// Returns the host computer name.
pub fn get_computer_name() -> String {
    std::env::var("COMPUTERNAME")
        .or_else(|_| std::env::var("HOSTNAME"))
        .unwrap_or_else(|_| "Windows PC".to_string())
}

/// Spawns the UDP auto-discovery responder and broadcast beacon.
pub fn spawn_discovery_beacon(state: Arc<HostState>) {
    std::thread::spawn(move || {
        let bind_addr = "0.0.0.0:4242";
        let socket = match UdpSocket::bind(bind_addr) {
            Ok(s) => s,
            Err(e) => {
                log::warn!("Could not bind UDP discovery on 4242: {}. Trying dynamic UDP port...", e);
                match UdpSocket::bind("0.0.0.0:0") {
                    Ok(s) => s,
                    Err(e) => {
                        log::error!("Failed to initialize UDP discovery: {}", e);
                        return;
                    }
                }
            }
        };

        let _ = socket.set_broadcast(true);
        let _ = socket.set_read_timeout(Some(Duration::from_millis(500)));

        log::info!("📡 UDP Auto-Discovery beacon active on {}", socket.local_addr().unwrap());

        let mut buf = [0u8; 512];
        let mut last_broadcast = Instant::now() - Duration::from_secs(10);
        let mut probe_window_start = Instant::now();
        let mut probe_reply_count = 0u32;

        loop {
            let ip = {
                state.local_ip.lock().map(|g| g.clone()).unwrap_or_else(|_| "127.0.0.1".to_string())
            };
            let beacon_payload = format!("PHONEPAD_HOST:{}:{}:{}:{}", ip, state.port, state.computer_name, state.auth_pin);

            // 1. Periodic broadcast announcement every 2 seconds
            if last_broadcast.elapsed() >= Duration::from_secs(2) {
                let broadcast_addr: SocketAddr = "255.255.255.255:4242".parse().unwrap();
                let _ = socket.send_to(beacon_payload.as_bytes(), broadcast_addr);
                last_broadcast = Instant::now();
            }

            // 2. Active probe response (with rate-limiting to prevent UDP amplification abuse)
            match socket.recv_from(&mut buf) {
                Ok((size, src)) => {
                    let msg = String::from_utf8_lossy(&buf[..size]);
                    if msg.trim().starts_with("PHONEPAD_DISCOVER") {
                        if probe_window_start.elapsed() >= Duration::from_secs(1) {
                            probe_window_start = Instant::now();
                            probe_reply_count = 0;
                        }

                        if probe_reply_count < 20 {
                            probe_reply_count += 1;
                            log::info!("🔍 Discovery probe received from {}", src);

                            // Dynamically identify the exact local interface IP that connects to src
                            let resolved_ip = if let Ok(probe_sock) = UdpSocket::bind("0.0.0.0:0") {
                                if probe_sock.connect(src).is_ok() {
                                    if let Ok(local_addr) = probe_sock.local_addr() {
                                        let ip_str = local_addr.ip().to_string();
                                        if ip_str != "127.0.0.1" && ip_str != "0.0.0.0" {
                                            if let Ok(mut g) = state.local_ip.lock() {
                                                if *g != ip_str {
                                                    *g = ip_str.clone();
                                                }
                                            }
                                            Some(ip_str)
                                        } else {
                                            None
                                        }
                                    } else {
                                        None
                                    }
                                } else {
                                    None
                                }
                            } else {
                                None
                            };

                            let active_ip = resolved_ip.unwrap_or_else(|| {
                                state.local_ip.lock().map(|g| g.clone()).unwrap_or_else(|_| "127.0.0.1".to_string())
                            });

                            let direct_payload = format!("PHONEPAD_HOST:{}:{}:{}:{}", active_ip, state.port, state.computer_name, state.auth_pin);
                            let _ = socket.send_to(direct_payload.as_bytes(), src);
                        } else {
                            log::warn!("🚨 Rate limit: Dropping excessive discovery probe from {}", src);
                        }
                    }
                }
                Err(ref e) if e.kind() == std::io::ErrorKind::WouldBlock || e.kind() == std::io::ErrorKind::TimedOut => {
                    // Normal timeout, continue loop
                }
                Err(_) => {
                    // Transient error, sleep briefly
                    std::thread::sleep(Duration::from_millis(200));
                }
            }
        }
    });
}
