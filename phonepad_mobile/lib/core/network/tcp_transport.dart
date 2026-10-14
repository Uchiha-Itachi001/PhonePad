import 'dart:async';
import 'dart:io';
import '../protocol/handshake.dart';
import '../protocol/opcode.dart';
import '../protocol/packet.dart';
import 'transport.dart';

class TcpTransport implements ITransport {
  Socket? _socket;
  final StreamController<ConnectionStatus> _statusController =
      StreamController<ConnectionStatus>.broadcast();
  ConnectionStatus _status = ConnectionStatus.disconnected;
  Timer? _keepAliveTimer;
  DateTime _lastPacketSent = DateTime.now();

  @override
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  @override
  ConnectionStatus get status => _status;

  void _setStatus(ConnectionStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(_status);
      if (newStatus == ConnectionStatus.connected) {
        _startKeepAlive();
      } else {
        _stopKeepAlive();
      }
    }
  }

  void _startKeepAlive() {
    _stopKeepAlive();
    _lastPacketSent = DateTime.now();
    _keepAliveTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      if (_status == ConnectionStatus.connected && _socket != null) {
        if (DateTime.now().difference(_lastPacketSent).inMilliseconds >= 1000) {
          sendPacket(const PhonePadPacket(opcode: Opcode.heartbeat));
        }
      }
    });
  }

  void _stopKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }

  int activePin = 0;

  void setPin(int pin) {
    activePin = pin;
  }

  @override
  Future<void> connect(String destination) async {
    _setStatus(ConnectionStatus.connecting);

    try {
      final parts = destination.split(':');
      final host = parts[0];
      final port = parts.length > 1 ? int.parse(parts[1]) : 4242;

      _socket = await Socket.connect(host, port, timeout: const Duration(seconds: 3));
      _socket!.setOption(SocketOption.tcpNoDelay, true);

      // Send initial secure HandshakeFrame with PIN
      final handshake = HandshakeFrame(
        deviceId: 0x1A2B3C4D,
        deviceType: DeviceType.phone,
        authPin: activePin,
      );
      _socket!.add(handshake.toBytes());

      _setStatus(ConnectionStatus.connected);

      _socket!.listen(
        (data) {
          // Handshake ack/heartbeat echo from host
        },
        onError: (error) {
          _setStatus(ConnectionStatus.disconnected);
          _socket?.destroy();
          _socket = null;
        },
        onDone: () {
          _setStatus(ConnectionStatus.disconnected);
          _socket?.destroy();
          _socket = null;
        },
        cancelOnError: true,
      );
    } catch (e) {
      _setStatus(ConnectionStatus.disconnected);
      rethrow;
    }
  }

  @override
  void sendPacket(PhonePadPacket packet) {
    if (_status == ConnectionStatus.connected && _socket != null) {
      try {
        _socket!.add(packet.toBytes());
        _lastPacketSent = DateTime.now();
      } catch (e) {
        _setStatus(ConnectionStatus.disconnected);
      }
    }
  }

  @override
  Future<void> disconnect() async {
    _stopKeepAlive();
    try {
      await _socket?.close();
    } catch (_) {}
    _socket?.destroy();
    _socket = null;
    _setStatus(ConnectionStatus.disconnected);
  }
}
