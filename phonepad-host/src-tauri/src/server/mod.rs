//! Server and connection management module.

pub mod connection;
pub mod discovery;
pub mod http_api;
pub mod listener;
pub mod security;
pub mod state;

pub use connection::SessionHandler;
pub use discovery::{get_computer_name, get_local_ip, spawn_discovery_beacon};
pub use http_api::run_http_api;
pub use listener::{run_tcp_server, ServerConfig};
pub use security::{is_same_subnet, is_trusted_http_origin, is_trusted_private_ip};
pub use state::HostState;

