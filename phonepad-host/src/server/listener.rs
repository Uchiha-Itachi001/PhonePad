//! Transport listener implementations (TCP stream server for ADB/Wi-Fi/Local & RFCOMM).

use super::connection::SessionHandler;
use super::state::HostState;
use crate::gesture::{BallisticsEngine, GestureFilter, GestureFsm};
use crate::input::create_default_injector;
use std::net::SocketAddr;
use std::sync::Arc;
use std::time::Duration;
use tokio::net::TcpListener;

pub struct ServerConfig {
    pub bind_addr: SocketAddr,
    pub idle_timeout: Duration,
}

impl Default for ServerConfig {
    fn default() -> Self {
        Self {
            bind_addr: "0.0.0.0:4242".parse().unwrap(),
            idle_timeout: Duration::from_secs(30),
        }
    }
}

/// Runs a persistent TCP server accepting PhonePad connections.
pub async fn run_tcp_server(
    config: ServerConfig,
    state: Arc<HostState>,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let listener = TcpListener::bind(config.bind_addr).await?;
    log::info!("⚡ PhonePad Host listening on {}", config.bind_addr);
    log::info!("Ready for client connections (via Bluetooth RFCOMM bridge, ADB reverse, or direct LAN).");

    loop {
        match listener.accept().await {
            Ok((stream, addr)) => {
                let _ = stream.set_nodelay(true);
                log::info!("📱 PhonePad client connected from {} (TCP_NODELAY enabled: 0ms buffering)", addr);

                let injector = create_default_injector();
                let ballistics = BallisticsEngine::default();
                let filter = GestureFilter::default();
                let fsm = GestureFsm::default();

                let mut session = SessionHandler::new(injector, ballistics, filter, fsm)
                    .with_state(state.clone());
                let timeout = config.idle_timeout;

                if !state.try_lock_session() {
                    log::warn!("🚨 SECURITY DEFENSE: Rejected concurrent connection from {}. Host is exclusively locked by an active session.", addr);
                    continue;
                }

                let session_state = state.clone();
                tokio::spawn(async move {
                    if let Err(e) = session.run_stream(stream, timeout).await {
                        log::error!("Session error with {}: {}", addr, e);
                    }
                    session_state.unlock_session();
                    log::info!("PhonePad client {} disconnected (Packets processed: {})", addr, session.packets_received);
                });
            }
            Err(e) => {
                log::error!("Listener accept error: {}", e);
            }
        }
    }
}
