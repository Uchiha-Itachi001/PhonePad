#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]
//! PhonePad Host Application — Wireless Trackpad Desktop Server.

pub mod companion;
pub mod gesture;
pub mod input;
pub mod protocol;
pub mod server;
pub mod ui;

use server::{get_computer_name, get_local_ip, run_http_api, run_tcp_server, spawn_discovery_beacon, HostState, ServerConfig};
use std::env;
use std::sync::Arc;

fn main() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    // Initialize logging
    let _ = env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).try_init();

    log::info!("=========================================");
    log::info!("  PhonePad Host Application (Desktop GUI) ");
    log::info!("  Multi-Wireless + Native Touch Engine    ");
    log::info!("=========================================");

    let mut port: u16 = 4242;
    if let Some(port_arg) = env::args().nth(1) {
        if let Ok(p) = port_arg.parse::<u16>() {
            port = p;
        }
    }

    let local_ip = get_local_ip();
    let computer_name = get_computer_name();

    // Generate secure 4-digit zero-trust pairing PIN (1000..=9999) using system time entropy
    let entropy = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_nanos())
        .unwrap_or(42424242);
    let auth_pin = ((entropy % 9000) + 1000) as u32;

    log::info!("Host IP: {}:{}, Host Name: {}, Pairing PIN: {:04}", local_ip, port, computer_name, auth_pin);

    let state = Arc::new(HostState::new(local_ip, port, computer_name, auth_pin));

    // 1. Spawn UDP Auto-Discovery responder and beacon
    spawn_discovery_beacon(state.clone());


    // 3. Spawn Tokio async runtime for TCP server and HTTP REST Control API
    let tcp_state = state.clone();
    let http_state = state.clone();
    let mut config = ServerConfig::default();
    config.bind_addr = format!("0.0.0.0:{}", port).parse().unwrap();

    std::thread::spawn(move || {
        let rt = tokio::runtime::Runtime::new().unwrap();
        rt.block_on(async move {
            let http_task = tokio::spawn(async move {
                if let Err(e) = run_http_api(http_state, 4243).await {
                    log::error!("HTTP API error: {}", e);
                }
            });

            let tcp_task = tokio::spawn(async move {
                if let Err(e) = run_tcp_server(config, tcp_state).await {
                    log::error!("TCP server error: {}", e);
                }
            });

            let _ = tokio::join!(http_task, tcp_task);
        });
    });

    // 4. Run native Windows Desktop GUI or Headless Daemon
    let is_headless = env::args().any(|a| a == "--headless" || a == "--daemon");
    if is_headless {
        log::info!("PhonePad Host running in headless daemon mode for React Desktop App");
        loop {
            std::thread::sleep(std::time::Duration::from_secs(60));
        }
    } else {
        #[cfg(windows)]
        {
            ui::run_desktop_window(state.clone());
        }

        #[cfg(not(windows))]
        {
            loop {
                std::thread::sleep(std::time::Duration::from_secs(60));
            }
        }
    }

    Ok(())
}
