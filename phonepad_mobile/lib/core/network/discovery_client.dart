import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Discovered PhonePad Host descriptor.
class DiscoveredHost {
  final String ip;
  final int port;
  final String name;
  final int pin;
  final DateTime lastSeen;

  const DiscoveredHost({
    required this.ip,
    required this.port,
    required this.name,
    this.pin = 0,
    required this.lastSeen,
  });

  String get destination => '$ip:$port';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredHost &&
          runtimeType == other.runtimeType &&
          ip == other.ip &&
          port == other.port;

  @override
  int get hashCode => ip.hashCode ^ port.hashCode;
}

/// UDP Auto-Discovery client for instant zero-config Wi-Fi host detection.
class DiscoveryClient {
  static const int defaultPort = 4242;

  RawDatagramSocket? _socket;
  Timer? _probeTimer;
  final Map<String, DiscoveredHost> _hosts = {};
  final StreamController<List<DiscoveredHost>> _hostsController =
      StreamController<List<DiscoveredHost>>.broadcast();

  Stream<List<DiscoveredHost>> get hostsStream => _hostsController.stream;
  List<DiscoveredHost> get currentHosts => _hosts.values.toList();

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  /// Starts listening for host beacons and broadcasting discovery probes.
  Future<void> startDiscovery() async {
    if (_isScanning) return;
    _isScanning = true;

    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket?.broadcastEnabled = true;

      _socket?.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket?.receive();
          if (datagram != null) {
            _handleDatagram(datagram);
          }
        }
      });

      // Send immediate probe
      sendDiscoveryProbe();

      // Repeat probe every 1.5 seconds while scanning
      _probeTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
        sendDiscoveryProbe();
      });
    } catch (_) {
      // Socket bind error handled gracefully
    }
  }

  /// Sends a broadcast discovery ping across local Wi-Fi.
  void sendDiscoveryProbe() {
    if (_socket == null) return;
    try {
      final payload = utf8.encode('PHONEPAD_DISCOVER');
      _socket?.send(
        payload,
        InternetAddress('255.255.255.255'),
        defaultPort,
      );
    } catch (_) {}
  }

  void _handleDatagram(Datagram datagram) {
    try {
      final message = utf8.decode(datagram.data).trim();
      if (message.startsWith('PHONEPAD_HOST:')) {
        final parts = message.split(':');
        if (parts.length >= 4) {
          final ip = parts[1].trim();
          final port = int.tryParse(parts[2].trim()) ?? defaultPort;
          final name = parts[3].trim();

          final resolvedIp = (ip == '127.0.0.1' || ip == '0.0.0.0')
              ? datagram.address.address
              : ip;
          final pin = parts.length >= 5 ? (int.tryParse(parts[4].trim()) ?? 0) : 0;

          final host = DiscoveredHost(
            ip: resolvedIp,
            port: port,
            name: name.isEmpty ? 'Windows PC' : name,
            pin: pin,
            lastSeen: DateTime.now(),
          );

          _hosts[host.destination] = host;
          _hostsController.add(_hosts.values.toList());
        }
      }
    } catch (_) {}
  }

  /// Quick 1-shot probe that resolves the first available PC within the timeout.
  Future<DiscoveredHost?> findFirstHost({
    Duration timeout = const Duration(milliseconds: 1800),
  }) async {
    if (_hosts.isNotEmpty) {
      return _hosts.values.first;
    }

    final completer = Completer<DiscoveredHost?>();
    StreamSubscription? sub;

    sub = hostsStream.listen((list) {
      if (list.isNotEmpty && !completer.isCompleted) {
        completer.complete(list.first);
      }
    });

    await startDiscovery();

    Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(_hosts.isNotEmpty ? _hosts.values.first : null);
      }
    });

    final result = await completer.future;
    await sub.cancel();
    return result;
  }

  /// Stops discovery probes and closes the socket.
  void stopDiscovery() {
    _isScanning = false;
    _probeTimer?.cancel();
    _socket?.close();
    _socket = null;
  }

  void dispose() {
    stopDiscovery();
    _hostsController.close();
  }
}
