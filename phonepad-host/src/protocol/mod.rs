//! Protocol module for PhonePad.

pub mod handshake;
pub mod opcode;
pub mod packet;

pub use handshake::{DeviceType, HandshakeFrame, HANDSHAKE_MAGIC, HANDSHAKE_SIZE};
pub use opcode::Opcode;
pub use packet::{Packet, FLAG_HIGH_RES, PACKET_SIZE};
