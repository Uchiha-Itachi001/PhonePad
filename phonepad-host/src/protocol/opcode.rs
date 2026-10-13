//! Protocol opcodes for PhonePad 6-byte binary packets.

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Opcode {
    /// 1-Finger relative movement delta (0x01)
    Move,
    /// 1-Finger tap / Left Click (0x02)
    TapLeft,
    /// 2-Finger tap / Right Click (0x03)
    TapRight,
    /// 2-Finger scroll delta (0x04)
    Scroll,
    /// Left button press / Drag start (0x05)
    DragStart,
    /// Left button release / Drag end (0x06)
    DragEnd,
    /// Middle mouse click (0x07)
    MiddleClick,
    /// Sleep / Standby idle command (0x10)
    SleepStandby,
    /// Virtual Numpad keystroke event (0x20)
    Numpad,
    /// Presentation and Media remote event (0x21)
    Media,
    /// Periodic heartbeat probe (0xFE)
    Heartbeat,
    /// Handshake acknowledgment or ping probe (0xFF)
    Ack,
    /// Unrecognized opcode fallback
    Unknown(u8),
}

impl From<u8> for Opcode {
    fn from(val: u8) -> Self {
        match val {
            0x01 => Opcode::Move,
            0x02 => Opcode::TapLeft,
            0x03 => Opcode::TapRight,
            0x04 => Opcode::Scroll,
            0x05 => Opcode::DragStart,
            0x06 => Opcode::DragEnd,
            0x07 => Opcode::MiddleClick,
            0x10 => Opcode::SleepStandby,
            0x20 => Opcode::Numpad,
            0x21 => Opcode::Media,
            0xFE => Opcode::Heartbeat,
            0xFF => Opcode::Ack,
            other => Opcode::Unknown(other),
        }
    }
}

impl From<Opcode> for u8 {
    fn from(opcode: Opcode) -> Self {
        match opcode {
            Opcode::Move => 0x01,
            Opcode::TapLeft => 0x02,
            Opcode::TapRight => 0x03,
            Opcode::Scroll => 0x04,
            Opcode::DragStart => 0x05,
            Opcode::DragEnd => 0x06,
            Opcode::MiddleClick => 0x07,
            Opcode::SleepStandby => 0x10,
            Opcode::Numpad => 0x20,
            Opcode::Media => 0x21,
            Opcode::Heartbeat => 0xFE,
            Opcode::Ack => 0xFF,
            Opcode::Unknown(val) => val,
        }
    }
}
