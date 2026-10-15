//! PhonePad 6-byte binary packet representation and zero-copy parser.

use super::opcode::Opcode;
use byteorder::{ByteOrder, LittleEndian};

pub const PACKET_SIZE: usize = 6;

/// Fixed 6-byte little-endian PhonePad touch packet.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Packet {
    pub opcode: Opcode,
    pub dx: i16,
    pub dy: i16,
    pub flags: u8,
}

impl Packet {
    pub fn new(opcode: Opcode, dx: i16, dy: i16, flags: u8) -> Self {
        Self { opcode, dx, dy, flags }
    }

    /// Parses a packet from a 6-byte buffer.
    pub fn from_bytes(buf: &[u8; PACKET_SIZE]) -> Self {
        let opcode = Opcode::from(buf[0]);
        let dx = LittleEndian::read_i16(&buf[1..3]);
        let dy = LittleEndian::read_i16(&buf[3..5]);
        let flags = buf[5];

        Self { opcode, dx, dy, flags }
    }

    /// Serializes the packet into a 6-byte buffer.
    pub fn to_bytes(&self) -> [u8; PACKET_SIZE] {
        let mut buf = [0u8; PACKET_SIZE];
        buf[0] = self.opcode.into();
        LittleEndian::write_i16(&mut buf[1..3], self.dx);
        LittleEndian::write_i16(&mut buf[3..5], self.dy);
        buf[5] = self.flags;
        buf
    }

    /// Bit 0: True if at least one finger is physically touching the digitizer.
    #[inline]
    pub fn is_touch_active(&self) -> bool {
        (self.flags & 0x01) != 0
    }

    /// Bits 1..2: Number of active pointers (0 to 3+).
    #[inline]
    pub fn finger_count(&self) -> u8 {
        (self.flags >> 1) & 0x03
    }

    /// Bit 3: Mobile client requested tactile haptic feedback.
    #[inline]
    pub fn haptic_requested(&self) -> bool {
        (self.flags & 0x08) != 0
    }

    /// Bit 4: Mobile client sending 8x sub-pixel high-resolution deltas (Q3 fixed point).
    #[inline]
    pub fn is_high_res(&self) -> bool {
        (self.flags & FLAG_HIGH_RES) != 0
    }

    /// Bit 5: Mobile client sending discrete wheel notches (e.g. remote scroll rocker).
    #[inline]
    pub fn is_discrete_notch(&self) -> bool {
        (self.flags & FLAG_DISCRETE_NOTCH) != 0
    }
}

pub const FLAG_HIGH_RES: u8 = 0x10;
pub const FLAG_DISCRETE_NOTCH: u8 = 0x20;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_packet_roundtrip_move() {
        let original = Packet::new(Opcode::Move, -320, 150, 0b00000011);
        let bytes = original.to_bytes();
        let parsed = Packet::from_bytes(&bytes);

        assert_eq!(parsed.opcode, Opcode::Move);
        assert_eq!(parsed.dx, -320);
        assert_eq!(parsed.dy, 150);
        assert_eq!(parsed.flags, 0b00000011);
        assert!(parsed.is_touch_active());
        assert_eq!(parsed.finger_count(), 1);
    }

    #[test]
    fn test_packet_roundtrip_scroll() {
        let original = Packet::new(Opcode::Scroll, 0, -45, 0b00000101);
        let bytes = original.to_bytes();
        let parsed = Packet::from_bytes(&bytes);

        assert_eq!(parsed.opcode, Opcode::Scroll);
        assert_eq!(parsed.dx, 0);
        assert_eq!(parsed.dy, -45);
        assert_eq!(parsed.finger_count(), 2);
    }

    #[test]
    fn test_packet_roundtrip_heartbeat() {
        let original = Packet::new(Opcode::Heartbeat, 0, 0, 0);
        let bytes = original.to_bytes();
        let parsed = Packet::from_bytes(&bytes);

        assert_eq!(parsed.opcode, Opcode::Heartbeat);
        assert_eq!(parsed.dx, 0);
        assert_eq!(parsed.dy, 0);
        assert!(!parsed.is_touch_active());
    }
}
