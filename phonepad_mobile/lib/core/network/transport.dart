import 'dart:async';
import '../protocol/packet.dart';

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

abstract class ITransport {
  Stream<ConnectionStatus> get statusStream;
  ConnectionStatus get status;

  Future<void> connect(String destination);
  void sendPacket(PhonePadPacket packet);
  Future<void> disconnect();
}
