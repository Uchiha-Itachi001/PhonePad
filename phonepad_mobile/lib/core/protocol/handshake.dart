import 'dart:typed_data';

const int handshakeMagic = 0xAA;
const int protocolVersion2 = 0x02;
const int handshakeSize = 12;

enum DeviceType {
  unknown(0),
  phone(1),
  tablet(2);

  final int value;
  const DeviceType(this.value);

  static DeviceType fromValue(int val) {
    switch (val) {
      case 1:
        return DeviceType.phone;
      case 2:
        return DeviceType.tablet;
      default:
        return DeviceType.unknown;
    }
  }
}

/// 12-byte initial handshake frame sent upon connection with security PIN.
class HandshakeFrame {
  final int magic;
  final int version;
  final int deviceId;
  final DeviceType deviceType;
  final int authPin;

  const HandshakeFrame({
    this.magic = handshakeMagic,
    this.version = protocolVersion2,
    required this.deviceId,
    this.deviceType = DeviceType.phone,
    this.authPin = 0,
  });

  Uint8List toBytes() {
    final byteData = ByteData(handshakeSize);
    byteData.setUint8(0, magic);
    byteData.setUint8(1, version);
    byteData.setUint32(2, deviceId, Endian.little);
    byteData.setUint16(6, deviceType.value, Endian.little);
    byteData.setUint32(8, authPin, Endian.little);
    return byteData.buffer.asUint8List();
  }

  factory HandshakeFrame.fromBytes(Uint8List bytes) {
    if (bytes.length < handshakeSize) {
      throw const FormatException('Buffer too small for HandshakeFrame');
    }
    final byteData = ByteData.sublistView(bytes);
    final magic = byteData.getUint8(0);
    if (magic != handshakeMagic) {
      throw const FormatException('Invalid handshake magic byte');
    }
    final version = byteData.getUint8(1);
    final deviceId = byteData.getUint32(2, Endian.little);
    final deviceTypeVal = byteData.getUint16(6, Endian.little);
    final authPin = byteData.getUint32(8, Endian.little);

    return HandshakeFrame(
      magic: magic,
      version: version,
      deviceId: deviceId,
      deviceType: DeviceType.fromValue(deviceTypeVal),
      authPin: authPin,
    );
  }
}
