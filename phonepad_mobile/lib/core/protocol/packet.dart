import 'dart:typed_data';

/// Fixed 6-byte little-endian PhonePad touch packet.
class PhonePadPacket {
  static const int packetSize = 6;

  final int opcode;
  final int dx;
  final int dy;
  final int flags;

  const PhonePadPacket({
    required this.opcode,
    this.dx = 0,
    this.dy = 0,
    this.flags = 0,
  });

  /// Serializes into a 6-byte binary frame matching Rust host layout.
  Uint8List toBytes() {
    final bytes = Uint8List(packetSize);
    final byteData = ByteData.sublistView(bytes);

    byteData.setUint8(0, opcode);
    byteData.setInt16(1, dx, Endian.little);
    byteData.setInt16(3, dy, Endian.little);
    byteData.setUint8(5, flags);

    return bytes;
  }

  /// Parses from a 6-byte binary frame.
  factory PhonePadPacket.fromBytes(Uint8List bytes) {
    if (bytes.length < packetSize) {
      throw ArgumentError('Packet buffer must be at least $packetSize bytes');
    }
    final byteData = ByteData.sublistView(bytes);
    return PhonePadPacket(
      opcode: byteData.getUint8(0),
      dx: byteData.getInt16(1, Endian.little),
      dy: byteData.getInt16(3, Endian.little),
      flags: byteData.getUint8(5),
    );
  }

  /// Bit 0: Touch contact actively detected.
  bool get isTouchActive => (flags & 0x01) != 0;

  /// Bits 1..2: Number of active pointers (0..3).
  int get fingerCount => (flags >> 1) & 0x03;

  /// Bit 3: Tactile haptic feedback requested.
  bool get hapticRequested => (flags & 0x08) != 0;
}
