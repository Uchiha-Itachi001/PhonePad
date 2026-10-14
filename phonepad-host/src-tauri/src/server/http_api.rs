//! HTTP REST Control API for PhonePad Desktop React Application.

use crate::server::state::HostState;
use std::sync::Arc;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpListener;

/// Runs lightweight HTTP control server on localhost for the React Desktop GUI.
pub async fn run_http_api(state: Arc<HostState>, port: u16) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let listener = TcpListener::bind(format!("127.0.0.1:{}", port)).await?;
    log::info!("PhonePad Host HTTP Control API listening on http://127.0.0.1:{}", port);

    loop {
        let (mut socket, _) = match listener.accept().await {
            Ok(s) => s,
            Err(e) => {
                log::warn!("HTTP accept error: {}", e);
                continue;
            }
        };

        let state = state.clone();
        tokio::spawn(async move {
            let mut buf = [0u8; 4096];
            let n = match socket.read(&mut buf).await {
                Ok(n) if n > 0 => n,
                _ => return,
            };

            let req_str = String::from_utf8_lossy(&buf[..n]);
            let first_line = req_str.lines().next().unwrap_or("");
            let parts: Vec<&str> = first_line.split_whitespace().collect();
            if parts.len() < 2 {
                return;
            }

            let method = parts[0];
            let path = parts[1];

            // Permissive CORS headers for local desktop client
            let cors_headers = "Access-Control-Allow-Origin: *\r\nAccess-Control-Allow-Methods: GET, POST, OPTIONS\r\nAccess-Control-Allow-Headers: Content-Type\r\n";

            if method == "OPTIONS" {
                let response = format!("HTTP/1.1 204 No Content\r\n{}\r\n", cors_headers);
                let _ = socket.write_all(response.as_bytes()).await;
                return;
            }

            if method == "GET" && (path == "/api/status" || path == "/status") {
                let is_connected = state.is_connected.load(std::sync::atomic::Ordering::Relaxed);
                let is_service_enabled = state.is_service_enabled.load(std::sync::atomic::Ordering::Relaxed);
                let local_ip = state.local_ip.lock().map(|s| s.clone()).unwrap_or_else(|_| "127.0.0.1".into());
                let client_name = state.client_name.lock().map(|s| s.clone()).unwrap_or_else(|_| "Waiting for connection...".into());
                let client_transport = state.client_transport.lock().map(|s| s.clone()).unwrap_or_else(|_| "None".into());
                let pps = state.packets_per_sec.load(std::sync::atomic::Ordering::Relaxed);
                let total = state.packets_total.load(std::sync::atomic::Ordering::Relaxed);
                let sensitivity = state.sensitivity.lock().map(|s| *s).unwrap_or(1.25);
                let natural_scroll = state.natural_scroll.load(std::sync::atomic::Ordering::Relaxed);
                let gestures_enabled = state.gestures_enabled.load(std::sync::atomic::Ordering::Relaxed);
                let tap_to_click = state.tap_to_click.load(std::sync::atomic::Ordering::Relaxed);

                let json = format!(
                    r#"{{"isRunning":true,"isServiceEnabled":{},"isConnected":{},"localIp":"{}","port":{},"computerName":"{}","authPin":{},"clientName":"{}","clientTransport":"{}","packetsPerSec":{},"totalPackets":{},"sensitivity":{:.2},"naturalScroll":{},"gesturesEnabled":{},"tapToClick":{}}}"#,
                    is_service_enabled,
                    is_connected,
                    local_ip,
                    state.port,
                    state.computer_name,
                    state.auth_pin,
                    client_name,
                    client_transport,
                    pps,
                    total,
                    sensitivity,
                    natural_scroll,
                    gestures_enabled,
                    tap_to_click
                );

                let response = format!(
                    "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n{}Content-Length: {}\r\n\r\n{}",
                    cors_headers,
                    json.len(),
                    json
                );
                let _ = socket.write_all(response.as_bytes()).await;
            } else if method == "POST" && path == "/api/service/toggle" {
                let current = state.is_service_enabled.load(std::sync::atomic::Ordering::SeqCst);
                let new_val = !current;
                state.is_service_enabled.store(new_val, std::sync::atomic::Ordering::SeqCst);

                let json = format!(r#"{{"isServiceEnabled":{}}}"#, new_val);
                let response = format!(
                    "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n{}Content-Length: {}\r\n\r\n{}",
                    cors_headers,
                    json.len(),
                    json
                );
                let _ = socket.write_all(response.as_bytes()).await;
            } else if method == "POST" && path == "/api/settings" {
                if let Some(body_start) = req_str.find("\r\n\r\n") {
                    let body = &req_str[body_start + 4..];
                    if let Some(sens_pos) = body.find("\"sensitivity\":") {
                        let rem = &body[sens_pos + 14..];
                        let val_str: String = rem.chars().take_while(|c| c.is_digit(10) || *c == '.').collect();
                        if let Ok(val) = val_str.parse::<f32>() {
                            if let Ok(mut s) = state.sensitivity.lock() {
                                *s = val;
                            }
                        }
                    }
                    if let Some(nat_pos) = body.find("\"naturalScroll\":") {
                        let rem = &body[nat_pos + 16..];
                        if rem.trim_start().starts_with("true") {
                            state.natural_scroll.store(true, std::sync::atomic::Ordering::Relaxed);
                        } else if rem.trim_start().starts_with("false") {
                            state.natural_scroll.store(false, std::sync::atomic::Ordering::Relaxed);
                        }
                    }
                    if let Some(gest_pos) = body.find("\"gesturesEnabled\":") {
                        let rem = &body[gest_pos + 18..];
                        if rem.trim_start().starts_with("true") {
                            state.gestures_enabled.store(true, std::sync::atomic::Ordering::Relaxed);
                        } else if rem.trim_start().starts_with("false") {
                            state.gestures_enabled.store(false, std::sync::atomic::Ordering::Relaxed);
                        }
                    }
                    if let Some(tap_pos) = body.find("\"tapToClick\":") {
                        let rem = &body[tap_pos + 13..];
                        if rem.trim_start().starts_with("true") {
                            state.tap_to_click.store(true, std::sync::atomic::Ordering::Relaxed);
                        } else if rem.trim_start().starts_with("false") {
                            state.tap_to_click.store(false, std::sync::atomic::Ordering::Relaxed);
                        }
                    }
                }

                let response = format!(
                    "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n{}Content-Length: 16\r\n\r\n{{\"success\":true}}",
                    cors_headers
                );
                let _ = socket.write_all(response.as_bytes()).await;
            } else if method == "POST" && path == "/api/shutdown" {
                let response = format!(
                    "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n{}Content-Length: 16\r\n\r\n{{\"success\":true}}",
                    cors_headers
                );
                let _ = socket.write_all(response.as_bytes()).await;
                std::process::exit(0);
            } else {
                let response = format!(
                    "HTTP/1.1 404 Not Found\r\n{}Content-Length: 0\r\n\r\n",
                    cors_headers
                );
                let _ = socket.write_all(response.as_bytes()).await;
            }
        });
    }
}
