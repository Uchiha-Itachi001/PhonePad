/// Protocol opcodes for PhonePad 6-byte binary packets.
abstract class Opcode {
  /// 1-Finger relative movement delta (0x01)
  static const int move = 0x01;

  /// 1-Finger tap / Left Click (0x02)
  static const int tapLeft = 0x02;

  /// 2-Finger tap / Right Click (0x03)
  static const int tapRight = 0x03;

  /// 2-Finger scroll delta (0x04)
  static const int scroll = 0x04;

  /// Left button press / Drag start (0x05)
  static const int dragStart = 0x05;

  /// Left button release / Drag end (0x06)
  static const int dragEnd = 0x06;

  /// Middle mouse click (0x07)
  static const int middleClick = 0x07;

  /// 2-Finger pinch zoom delta (0x08)
  static const int zoom = 0x08;

  /// Sleep / Standby idle command (0x10)
  static const int sleepStandby = 0x10;

  /// Virtual Numpad keystroke event (0x20)
  static const int numpad = 0x20;

  /// Presentation and Media remote event (0x21)
  static const int media = 0x21;

  /// Virtual Keyboard keystroke event (0x22)
  static const int keyboard = 0x22;

  /// Periodic heartbeat probe (0xFE)
  static const int heartbeat = 0xFE;

  /// Handshake acknowledgment or ping probe (0xFF)
  static const int ack = 0xFF;
}
