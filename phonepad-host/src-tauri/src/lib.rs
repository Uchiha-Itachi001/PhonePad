pub mod companion;
pub mod gesture;
pub mod input;
pub mod protocol;
pub mod server;
pub mod ui;

use serde::{Deserialize, Serialize};
use server::{get_computer_name, get_local_ip, run_http_api, run_tcp_server, spawn_discovery_beacon, HostState, ServerConfig};
use std::sync::Arc;
use tauri::{
    menu::{Menu, MenuItem},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    Emitter, Manager,
};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HostStatusDto {
    pub is_running: bool,
    pub is_service_enabled: bool,
    pub is_connected: bool,
    pub local_ip: String,
    pub port: u16,
    pub computer_name: String,
    pub auth_pin: u32,
    pub client_name: String,
    pub client_transport: String,
    pub packets_per_sec: u32,
    pub total_packets: u64,
    pub sensitivity: f32,
    pub natural_scroll: bool,
    pub gestures_enabled: bool,
    pub tap_to_click: bool,
    pub qr_payload: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UpdateSettingsDto {
    pub sensitivity: Option<f32>,
    pub natural_scroll: Option<bool>,
    pub gestures_enabled: Option<bool>,
    pub tap_to_click: Option<bool>,
}

#[tauri::command]
fn get_host_status(state: tauri::State<Arc<HostState>>) -> HostStatusDto {
    let is_connected = state.is_connected.load(std::sync::atomic::Ordering::Relaxed);
    let is_service_enabled = state.is_service_enabled.load(std::sync::atomic::Ordering::Relaxed);
    let local_ip = state.local_ip.lock().map(|s| s.clone()).unwrap_or_else(|_| "127.0.0.1".into());
    let client_name = state.client_name.lock().map(|s| s.clone()).unwrap_or_else(|_| "Waiting for connection...".into());
    let client_transport = state.client_transport.lock().map(|s| s.clone()).unwrap_or_else(|_| "None".into());
    let packets_per_sec = state.packets_per_sec.load(std::sync::atomic::Ordering::Relaxed);
    let total_packets = state.packets_total.load(std::sync::atomic::Ordering::Relaxed);
    let sensitivity = state.sensitivity.lock().map(|s| *s).unwrap_or(1.25);
    let natural_scroll = state.natural_scroll.load(std::sync::atomic::Ordering::Relaxed);
    let gestures_enabled = state.gestures_enabled.load(std::sync::atomic::Ordering::Relaxed);
    let tap_to_click = state.tap_to_click.load(std::sync::atomic::Ordering::Relaxed);

    let qr_payload = format!(
        "phonepad://connect?ip={}&port={}&name={}&pin={}",
        local_ip, state.port, state.computer_name, state.auth_pin
    );

    HostStatusDto {
        is_running: true,
        is_service_enabled,
        is_connected,
        local_ip,
        port: state.port,
        computer_name: state.computer_name.clone(),
        auth_pin: state.auth_pin,
        client_name,
        client_transport,
        packets_per_sec,
        total_packets,
        sensitivity,
        natural_scroll,
        gestures_enabled,
        tap_to_click,
        qr_payload,
    }
}

#[tauri::command]
fn toggle_service(state: tauri::State<Arc<HostState>>) -> bool {
    let current = state.is_service_enabled.load(std::sync::atomic::Ordering::SeqCst);
    let new_val = !current;
    state.is_service_enabled.store(new_val, std::sync::atomic::Ordering::SeqCst);
    new_val
}

#[tauri::command]
fn set_service_enabled(state: tauri::State<Arc<HostState>>, enabled: bool) -> bool {
    state.is_service_enabled.store(enabled, std::sync::atomic::Ordering::SeqCst);
    enabled
}

#[tauri::command]
fn update_settings(state: tauri::State<Arc<HostState>>, settings: UpdateSettingsDto) -> bool {
    if let Some(sens) = settings.sensitivity {
        if let Ok(mut s) = state.sensitivity.lock() {
            *s = sens;
        }
    }
    if let Some(nat) = settings.natural_scroll {
        state.natural_scroll.store(nat, std::sync::atomic::Ordering::Relaxed);
    }
    if let Some(gest) = settings.gestures_enabled {
        state.gestures_enabled.store(gest, std::sync::atomic::Ordering::Relaxed);
    }
    if let Some(tap) = settings.tap_to_click {
        state.tap_to_click.store(tap, std::sync::atomic::Ordering::Relaxed);
    }
    true
}

#[tauri::command]
fn get_pairing_qr_payload(state: tauri::State<Arc<HostState>>) -> String {
    let local_ip = state.local_ip.lock().map(|s| s.clone()).unwrap_or_else(|_| "127.0.0.1".into());
    format!(
        "phonepad://connect?ip={}&port={}&name={}&pin={}",
        local_ip, state.port, state.computer_name, state.auth_pin
    )
}

#[tauri::command]
fn minimize_window(window: tauri::WebviewWindow) {
    let _ = window.minimize();
}

#[tauri::command]
fn hide_window(window: tauri::WebviewWindow) {
    let _ = window.hide();
}

#[tauri::command]
fn exit_app(app_handle: tauri::AppHandle) {
    app_handle.exit(0);
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    // 1. Single-instance enforcement using Win32 Mutex
    #[cfg(windows)]
    {
        let mutex_name: Vec<u16> = "Global\\PhonePad_SingleInstance_Mutex\0".encode_utf16().collect();
        let _mutex = unsafe {
            windows::Win32::System::Threading::CreateMutexW(
                None,
                false,
                windows::core::PCWSTR(mutex_name.as_ptr()),
            )
        };
        if unsafe { windows::Win32::Foundation::GetLastError() }
            == windows::Win32::Foundation::ERROR_ALREADY_EXISTS
        {
            eprintln!("[phonepad-host] Another instance is already running.");
            return;
        }
    }

    // 2. Initialize env_logger
    let _ = env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).try_init();

    log::info!("=========================================");
    log::info!("  PhonePad Host — Tauri Desktop Engine  ");
    log::info!("=========================================");

    let port: u16 = 4242;
    let local_ip = get_local_ip();
    let computer_name = get_computer_name();

    let entropy = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_nanos())
        .unwrap_or(42424242);
    let auth_pin = ((entropy % 9000) + 1000) as u32;

    log::info!("Host IP: {}:{}, Host Name: {}, Pairing PIN: {:04}", local_ip, port, computer_name, auth_pin);

    let state = Arc::new(HostState::new(local_ip, port, computer_name, auth_pin));

    // Spawn UDP beacon & auto-discovery
    spawn_discovery_beacon(state.clone());

    // Spawn Tokio runtime for TCP server & HTTP REST API
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

    let app_state = state.clone();

    // 3. Ensure WebView2 compositor initializes with transparent surface
    std::env::set_var("WEBVIEW2_DEFAULT_BACKGROUND_COLOR", "0");

    let app = tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .manage(app_state)
        .invoke_handler(tauri::generate_handler![
            get_host_status,
            toggle_service,
            set_service_enabled,
            update_settings,
            get_pairing_qr_payload,
            minimize_window,
            hide_window,
            exit_app,
        ])
        .setup(|app| {
            // Setup System Tray
            let show_item = MenuItem::with_id(app, "show", "Open PhonePad", true, None::<&str>)?;
            let toggle_item = MenuItem::with_id(app, "toggle", "Toggle Active / Paused", true, None::<&str>)?;
            let quit_item = MenuItem::with_id(app, "quit", "Exit PhonePad", true, None::<&str>)?;
            let menu = Menu::with_items(app, &[&show_item, &toggle_item, &quit_item])?;

            let _tray = TrayIconBuilder::new()
                .icon(app.default_window_icon().unwrap().clone())
                .menu(&menu)
                .show_menu_on_left_click(false)
                .tooltip("PhonePad Host — Wireless Trackpad")
                .on_menu_event(|app, event| match event.id.as_ref() {
                    "show" => {
                        if let Some(window) = app.get_webview_window("main") {
                            let _ = window.show();
                            let _ = window.unminimize();
                            let _ = window.set_focus();
                        }
                    }
                    "toggle" => {
                        if let Some(state) = app.try_state::<Arc<HostState>>() {
                            let cur = state.is_service_enabled.load(std::sync::atomic::Ordering::SeqCst);
                            state.is_service_enabled.store(!cur, std::sync::atomic::Ordering::SeqCst);
                        }
                    }
                    "quit" => {
                        app.exit(0);
                    }
                    _ => {}
                })
                .on_tray_icon_event(|tray, event| {
                    if let TrayIconEvent::Click {
                        button: MouseButton::Left,
                        button_state: MouseButtonState::Up,
                        ..
                    } = event
                    {
                        let app = tray.app_handle();
                        if let Some(window) = app.get_webview_window("main") {
                            let _ = window.show();
                            let _ = window.unminimize();
                            let _ = window.set_focus();
                        }
                    }
                })
                .build(app)?;

            // Background telemetry emitter (10 Hz = 100ms interval)
            let state_clone = app.state::<Arc<HostState>>().inner().clone();
            let app_handle = app.handle().clone();
            std::thread::spawn(move || {
                loop {
                    std::thread::sleep(std::time::Duration::from_millis(100));
                    if let Some(window) = app_handle.get_webview_window("main") {
                        if window.is_visible().unwrap_or(false) {
                            let is_connected = state_clone.is_connected.load(std::sync::atomic::Ordering::Relaxed);
                            let is_service_enabled = state_clone.is_service_enabled.load(std::sync::atomic::Ordering::Relaxed);
                            let pps = state_clone.packets_per_sec.load(std::sync::atomic::Ordering::Relaxed);
                            let total = state_clone.packets_total.load(std::sync::atomic::Ordering::Relaxed);
                            let client_name = state_clone.client_name.lock().map(|s| s.clone()).unwrap_or_else(|_| "None".into());
                            let client_transport = state_clone.client_transport.lock().map(|s| s.clone()).unwrap_or_else(|_| "None".into());
                            
                            let _ = window.emit("host-telemetry", serde_json::json!({
                                "isConnected": is_connected,
                                "isServiceEnabled": is_service_enabled,
                                "packetsPerSec": pps,
                                "totalPackets": total,
                                "clientName": client_name,
                                "clientTransport": client_transport,
                            }));
                        }
                    }
                }
            });

            Ok(())
        })
        .build(tauri::generate_context!())
        .expect("error while building PhonePad Host");

    app.run(|_app_handle, _event| {});
}
