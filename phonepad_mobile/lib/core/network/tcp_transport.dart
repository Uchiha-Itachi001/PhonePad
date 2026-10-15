import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
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

  String? _lastDestination;
  bool _isManualDisconnect = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

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
      } else if (newStatus == ConnectionStatus.disconnected) {
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

  final Uint8List _packetBuffer = Uint8List(PhonePadPacket.packetSize);

  @override
  Future<void> connect(String destination) async {
    _isManualDisconnect = false;
    _lastDestination = destination;
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    return _internalConnect(destination);
  }

  Future<void> _internalConnect(String destination) async {
    if (_reconnectAttempts == 0) {
      _setStatus(ConnectionStatus.connecting);
    } else {
      _setStatus(ConnectionStatus.reconnecting);
    }

    try {
      final trimmed = destination.trim();
      final lastColon = trimmed.lastIndexOf(':');
      String host;
      int port = 4242;
      if (lastColon != -1 && lastColon < trimmed.length - 1) {
        host = trimmed.substring(0, lastColon).replaceAll('[', '').replaceAll(']', '').trim();
        port = int.tryParse(trimmed.substring(lastColon + 1).trim()) ?? 4242;
      } else {
        host = trimmed.replaceAll('[', '').replaceAll(']', '').trim();
      }
      if (host.isEmpty) host = '127.0.0.1';

      _socket = await Socket.connect(host, port, timeout: const Duration(seconds: 3));
      _socket!.setOption(SocketOption.tcpNoDelay, true);

      // Send initial secure HandshakeFrame with PIN
      final handshake = HandshakeFrame(
        deviceId: 0x1A2B3C4D,
        deviceType: DeviceType.phone,
        authPin: activePin,
      );
      _socket!.add(handshake.toBytes());
      _socket!.flush().catchError((_) {});

      _reconnectAttempts = 0;
      _setStatus(ConnectionStatus.connected);

      _socket!.listen(
        (data) {
          // Handshake ack/heartbeat echo from host
        },
        onError: (error) {
          _handleUnexpectedDrop();
        },
        onDone: () {
          _handleUnexpectedDrop();
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (_reconnectAttempts > 0) {
        _handleUnexpectedDrop();
      } else {
        _setStatus(ConnectionStatus.disconnected);
        rethrow;
      }
    }
  }

  void _handleUnexpectedDrop() {
    _stopKeepAlive();
    try {
      _socket?.destroy();
    } catch (_) {}
    _socket = null;

    if (_isManualDisconnect || _lastDestination == null) {
      _setStatus(ConnectionStatus.disconnected);
      return;
    }

    // Auto-reconnect with exponential backoff on accidental WiFi / network drop
    if (_reconnectAttempts < 3) {
      _reconnectAttempts++;
      _setStatus(ConnectionStatus.reconnecting);
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(Duration(milliseconds: 600 * _reconnectAttempts), () async {
        if (!_isManualDisconnect && _lastDestination != null) {
          try {
            await _internalConnect(_lastDestination!);
          } catch (_) {
            // Handled inside _internalConnect
          }
        }
      });
    } else {
      _reconnectAttempts = 0;
      _setStatus(ConnectionStatus.disconnected);
    }
  }

  @override
  void sendPacket(PhonePadPacket packet) {
    if (_status == ConnectionStatus.connected && _socket != null) {
      try {
        packet.writeTo(_packetBuffer);
        _socket!.add(_packetBuffer);
        // Flush immediately to reduce transmission latency down to wire speed
        _socket!.flush().catchError((_) {});
        _lastPacketSent = DateTime.now();
      } catch (e) {
        _handleUnexpectedDrop();
      }
    }
  }

  @override
  Future<void> disconnect() async {
    _isManualDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    _stopKeepAlive();
    try {
      await _socket?.close();
    } catch (_) {}
    _socket?.destroy();
    _socket = null;
    _setStatus(ConnectionStatus.disconnected);
  }
}
