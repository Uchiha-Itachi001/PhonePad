//! Device Handshake Identification Frame (12 bytes) with security PIN authentication.

use byteorder::{ByteOrder, LittleEndian};

pub const HANDSHAKE_MAGIC: u8 = 0xAA;
pub const PROTOCOL_VERSION_1: u8 = 0x01;
pub const PROTOCOL_VERSION_2: u8 = 0x02;
pub const HANDSHAKE_SIZE: usize = 12;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DeviceType {
    Phone = 0x01,
    Tablet = 0x02,
    Unknown = 0x00,
}

impl From<u16> for DeviceType {
    fn from(val: u16) -> Self {
        match val {
            0x01 => DeviceType::Phone,
            0x02 => DeviceType::Tablet,
            _ => DeviceType::Unknown,
        }
    }
}

/// 12-byte initial handshake frame sent upon connection with security PIN.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct HandshakeFrame {
    pub magic: u8,
    pub version: u8,
    pub device_id: u32,
    pub device_type: DeviceType,
    pub auth_pin: u32,
}

impl HandshakeFrame {
    pub fn new(device_id: u32, device_type: DeviceType, auth_pin: u32) -> Self {
        Self {
            magic: HANDSHAKE_MAGIC,
            version: PROTOCOL_VERSION_2,
            device_id,
            device_type,
            auth_pin,
        }
    }

    pub fn to_bytes(&self) -> [u8; HANDSHAKE_SIZE] {
        let mut buf = [0u8; HANDSHAKE_SIZE];
        buf[0] = self.magic;
        buf[1] = self.version;
        LittleEndian::write_u32(&mut buf[2..6], self.device_id);
        LittleEndian::write_u16(&mut buf[6..8], self.device_type as u16);
        LittleEndian::write_u32(&mut buf[8..12], self.auth_pin);
        buf
    }

    pub fn from_bytes(buf: &[u8; HANDSHAKE_SIZE]) -> Result<Self, &'static str> {
        if buf[0] != HANDSHAKE_MAGIC {
            return Err("Invalid handshake magic byte");
        }
        let version = buf[1];
        if version != PROTOCOL_VERSION_1 && version != PROTOCOL_VERSION_2 {
            return Err("Unsupported handshake protocol version");
        }
        let device_id = LittleEndian::read_u32(&buf[2..6]);
        let device_type = DeviceType::from(LittleEndian::read_u16(&buf[6..8]));
        if device_type == DeviceType::Unknown {
            return Err("Invalid or unrecognized client device type");
        }
        let auth_pin = LittleEndian::read_u32(&buf[8..12]);

        Ok(Self {
            magic: buf[0],
            version,
            device_id,
            device_type,
            auth_pin,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_handshake_roundtrip() {
        let original = HandshakeFrame::new(0x9A4F12C3, DeviceType::Phone, 4829);
        let bytes = original.to_bytes();
        let parsed = HandshakeFrame::from_bytes(&bytes).expect("Valid handshake");

        assert_eq!(parsed.magic, HANDSHAKE_MAGIC);
        assert_eq!(parsed.version, PROTOCOL_VERSION_2);
        assert_eq!(parsed.device_id, 0x9A4F12C3);
        assert_eq!(parsed.device_type, DeviceType::Phone);
        assert_eq!(parsed.auth_pin, 4829);
    }

    #[test]
    fn test_invalid_magic_rejected() {
        let buf = [0x55, 0x02, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0];
        assert!(HandshakeFrame::from_bytes(&buf).is_err());
    }
}
