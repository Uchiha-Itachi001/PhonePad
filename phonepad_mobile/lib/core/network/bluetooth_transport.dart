import 'dart:async';
import 'package:flutter/services.dart';
import '../protocol/handshake.dart';
import '../protocol/packet.dart';
import 'transport.dart';

class BluetoothDeviceInfo {
  final String name;
  final String address;

  const BluetoothDeviceInfo({required this.name, required this.address});

  factory BluetoothDeviceInfo.fromMap(Map<dynamic, dynamic> map) {
    return BluetoothDeviceInfo(
      name: map['name'] as String? ?? 'Unknown Device',
      address: map['address'] as String? ?? '',
    );
  }
}

/// Native Bluetooth RFCOMM (Serial Port Profile - SPP) transport.
class BluetoothTransport implements ITransport {
  static const MethodChannel _channel = MethodChannel('com.pankoj.phonepad/bluetooth');

  final StreamController<ConnectionStatus> _statusController =
      StreamController<ConnectionStatus>.broadcast();
  ConnectionStatus _status = ConnectionStatus.disconnected;

  BluetoothTransport() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onStatusChanged') {
      final statusStr = call.arguments as String?;
      switch (statusStr) {
        case 'connecting':
          _setStatus(ConnectionStatus.connecting);
          break;
        case 'connected':
          _setStatus(ConnectionStatus.connected);
          break;
        case 'disconnected':
        default:
          _setStatus(ConnectionStatus.disconnected);
          break;
      }
    }
  }

  void _setStatus(ConnectionStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(_status);
    }
  }

  @override
  ConnectionStatus get status => _status;

  @override
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  /// Requests Bluetooth runtime permissions on Android 12+.
  Future<void> requestPermissions() async {
    try {
      await _channel.invokeMethod('requestPermissions');
    } catch (_) {}
  }

  /// Fetches Bluetooth devices paired with this phone.
  Future<List<BluetoothDeviceInfo>> getPairedDevices() async {
    try {
      final List<dynamic>? rawList =
          await _channel.invokeMethod<List<dynamic>>('getPairedDevices');
      if (rawList == null) return [];
      return rawList
          .map((item) => BluetoothDeviceInfo.fromMap(item as Map<dynamic, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> connect(String destination) async {
    _setStatus(ConnectionStatus.connecting);
    try {
      await _channel.invokeMethod('connect', {'address': destination});

      // Send initial Phase 3 handshake frame over Bluetooth
      const handshake = HandshakeFrame(
        deviceId: 0x1A2B3C4D,
        deviceType: DeviceType.phone,
      );
      sendPacketRaw(handshake.toBytes());

      _setStatus(ConnectionStatus.connected);
    } catch (e) {
      _setStatus(ConnectionStatus.disconnected);
      rethrow;
    }
  }

  @override
  void sendPacket(PhonePadPacket packet) {
    if (_status == ConnectionStatus.connected) {
      sendPacketRaw(packet.toBytes());
    }
  }

  void sendPacketRaw(Uint8List bytes) {
    try {
      _channel.invokeMethod('sendBytes', {'bytes': bytes});
    } catch (_) {
      _setStatus(ConnectionStatus.disconnected);
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await _channel.invokeMethod('disconnect');
    } catch (_) {}
    _setStatus(ConnectionStatus.disconnected);
  }
}
