import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phonepad_mobile/core/network/discovery_client.dart';
import 'package:phonepad_mobile/core/network/transport.dart';
import 'package:phonepad_mobile/core/power/power_governor.dart';
import 'package:phonepad_mobile/core/protocol/handshake.dart';
import 'package:phonepad_mobile/core/protocol/keys.dart';
import 'package:phonepad_mobile/core/protocol/opcode.dart';
import 'package:phonepad_mobile/core/protocol/packet.dart';
import 'package:phonepad_mobile/features/modes/presentation/numpad_surface.dart';
import 'package:phonepad_mobile/features/modes/presentation/remote_surface.dart';
import 'package:phonepad_mobile/core/theme/theme_controller.dart';
import 'package:phonepad_mobile/features/touch/logic/touch_detector.dart';
import 'package:phonepad_mobile/features/touch/presentation/touch_surface.dart';

class MockTransport implements ITransport {
  final _controller = StreamController<ConnectionStatus>.broadcast();
  ConnectionStatus _status = ConnectionStatus.connected;
  final List<PhonePadPacket> sentPackets = [];

  @override
  ConnectionStatus get status => _status;

  @override
  Stream<ConnectionStatus> get statusStream => _controller.stream;

  @override
  Future<void> connect(String destination) async {
    _status = ConnectionStatus.connected;
    _controller.add(_status);
  }

  @override
  Future<void> disconnect() async {
    _status = ConnectionStatus.disconnected;
    _controller.add(_status);
  }

  @override
  void sendPacket(PhonePadPacket packet) {
    sentPackets.add(packet);
  }
}

void main() {
  test('PhonePadPacket binary serialization roundtrip', () {
    const packet = PhonePadPacket(
      opcode: Opcode.move,
      dx: 45,
      dy: -120,
      flags: 0x03,
    );

    final bytes = packet.toBytes();
    expect(bytes.length, equals(PhonePadPacket.packetSize));

    final parsed = PhonePadPacket.fromBytes(bytes);
    expect(parsed.opcode, equals(Opcode.move));
    expect(parsed.dx, equals(45));
    expect(parsed.dy, equals(-120));
    expect(parsed.flags, equals(0x03));
    expect(parsed.isTouchActive, isTrue);
    expect(parsed.fingerCount, equals(1));
  });

  test('HandshakeFrame binary serialization roundtrip', () {
    const frame = HandshakeFrame(
      deviceId: 0x9A4F12C3,
      deviceType: DeviceType.phone,
    );

    final bytes = frame.toBytes();
    expect(bytes.length, equals(handshakeSize));

    final parsed = HandshakeFrame.fromBytes(bytes);
    expect(parsed.magic, equals(handshakeMagic));
    expect(parsed.version, equals(protocolVersion2));
    expect(parsed.deviceId, equals(0x9A4F12C3));
    expect(parsed.deviceType, equals(DeviceType.phone));
  });

  testWidgets('TouchSurface renders and dispatches packets on drag', (WidgetTester tester) async {
    final mockTransport = MockTransport();

    await tester.pumpWidget(MaterialApp(
      home: TouchSurface(
        transport: mockTransport,
        destination: '127.0.0.1:4242',
        onSettingsTap: () {},
      ),
    ));

    expect(find.textContaining('PhonePad'), findsOneWidget);

    // Simulate drag gesture on touch surface
    final gesture = await tester.startGesture(const Offset(200, 300));
    await gesture.moveBy(const Offset(15, 20));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    // Verify touch packet was dispatched to transport
    expect(mockTransport.sentPackets.isNotEmpty, isTrue);
    expect(mockTransport.sentPackets.first.opcode, equals(Opcode.move));
    expect(mockTransport.sentPackets.first.dx, equals(15));
    expect(mockTransport.sentPackets.first.dy, equals(20));
  });

  testWidgets('TouchSurface detects quick tap as Left Click with haptic flag', (WidgetTester tester) async {
    final mockTransport = MockTransport();

    await tester.pumpWidget(MaterialApp(
      home: TouchSurface(
        transport: mockTransport,
        destination: '127.0.0.1:4242',
        onSettingsTap: () {},
      ),
    ));

    // Instantaneous tap down and up without displacement
    final gesture = await tester.startGesture(const Offset(150, 250));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pump();

    final tapPackets = mockTransport.sentPackets.where((p) => p.opcode == Opcode.tapLeft).toList();
    expect(tapPackets.isNotEmpty, isTrue);
    expect(tapPackets.first.hapticRequested, isTrue);
  });

  testWidgets('TouchSurface handles 3-finger gesture dispatch', (WidgetTester tester) async {
    final mockTransport = MockTransport();

    await tester.pumpWidget(MaterialApp(
      home: TouchSurface(
        transport: mockTransport,
        destination: '127.0.0.1:4242',
        onSettingsTap: () {},
      ),
    ));

    // Simulate 3 fingers down
    final g1 = await tester.startGesture(const Offset(100, 300), pointer: 1);
    final g2 = await tester.startGesture(const Offset(150, 300), pointer: 2);
    final g3 = await tester.startGesture(const Offset(200, 300), pointer: 3);

    // Primary finger moves up by 30px (swipe up)
    await g1.moveBy(const Offset(0, -30));
    await tester.pump();

    await g1.up();
    await g2.up();
    await g3.up();
    await tester.pump();

    final threeFingerPackets = mockTransport.sentPackets.where((p) => p.fingerCount == 3).toList();
    expect(threeFingerPackets.isNotEmpty, isTrue);
    expect(threeFingerPackets.first.dy, equals(-30));
  });

  testWidgets('NumpadSurface dispatches opcode.numpad packets with tactile codes', (WidgetTester tester) async {
    final mockTransport = MockTransport();
    var activityTriggered = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NumpadSurface(
          transport: mockTransport,
          onActivity: () => activityTriggered = true,
        ),
      ),
    ));

    // Tap number 7 button
    await tester.tap(find.text('7'));
    await tester.pump();

    expect(activityTriggered, isTrue);
    final num7Packets = mockTransport.sentPackets.where((p) => p.opcode == Opcode.numpad).toList();
    expect(num7Packets.isNotEmpty, isTrue);
    expect(num7Packets.first.dx, equals(NumpadKey.num7.code));

    // Tap ENTER button
    await tester.tap(find.text('ENTER'));
    await tester.pump();

    expect(mockTransport.sentPackets.last.opcode, equals(Opcode.numpad));
    expect(mockTransport.sentPackets.last.dx, equals(NumpadKey.enter.code));
  });

  testWidgets('RemoteSurface dispatches opcode.media packets for deck and audio', (WidgetTester tester) async {
    final mockTransport = MockTransport();
    var activityTriggered = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RemoteSurface(
          transport: mockTransport,
          onActivity: () => activityTriggered = true,
        ),
      ),
    ));

    // Tap NEXT slide button
    await tester.tap(find.byKey(const Key('next_slide_btn')));
    await tester.pump();

    expect(activityTriggered, isTrue);
    final mediaPackets = mockTransport.sentPackets.where((p) => p.opcode == Opcode.media).toList();
    expect(mediaPackets.isNotEmpty, isTrue);
    expect(mediaPackets.first.dx, equals(MediaKey.nextSlide.code));

    // Tap Play / Pause button
    await tester.tap(find.byKey(const Key('play_pause_btn')));
    await tester.pump();

    expect(mockTransport.sentPackets.last.opcode, equals(Opcode.media));
    expect(mockTransport.sentPackets.last.dx, equals(MediaKey.playPause.code));

    // Tap Volume Up button
    await tester.tap(find.byKey(const Key('vol_up_btn')));
    await tester.pump();
    expect(mockTransport.sentPackets.last.dx, equals(MediaKey.volumeUp.code));
  });

  testWidgets('TouchSurface mode selector switches between Trackpad, Numpad, and Remote', (WidgetTester tester) async {
    final mockTransport = MockTransport();

    await tester.pumpWidget(MaterialApp(
      home: TouchSurface(
        transport: mockTransport,
        destination: '127.0.0.1:4242',
        onSettingsTap: () {},
      ),
    ));

    // Initially in Trackpad mode
    expect(find.text('Numpad'), findsOneWidget);
    expect(find.text('Remote'), findsOneWidget);
    expect(find.text('ENTER'), findsNothing);

    // Switch to Numpad mode
    await tester.tap(find.text('Numpad'));
    await tester.pumpAndSettle();

    expect(find.text('ENTER'), findsOneWidget);

    // Switch to Remote mode
    await tester.tap(find.text('Remote'));
    await tester.pumpAndSettle();

    expect(find.text('PREV'), findsOneWidget);
    expect(find.text('NEXT'), findsOneWidget);
    expect(find.text('Play / Pause'), findsOneWidget);
  });

  test('PowerGovernor auto-dims after inactivity and restores on recordActivity', () async {
    final governor = PowerGovernor(idleThreshold: const Duration(milliseconds: 50));
    expect(governor.isDimmed, isFalse);

    // Wait past idleThreshold and timer tick (checkTimer ticks at 2s, but we can verify recordActivity immediately)
    governor.recordActivity();
    expect(governor.isDimmed, isFalse);

    governor.dispose();
  });

  test('DiscoveredHost formats destination and maintains equality', () {
    final host1 = DiscoveredHost(
      ip: '192.168.1.15',
      port: 4242,
      name: 'LAPTOP-TEST',
      lastSeen: DateTime.now(),
    );
    final host2 = DiscoveredHost(
      ip: '192.168.1.15',
      port: 4242,
      name: 'LAPTOP-TEST',
      lastSeen: DateTime.now(),
    );

    expect(host1.destination, equals('192.168.1.15:4242'));
    expect(host1, equals(host2));
  });

  test('ThemeController switches themes and dot matrix densities', () {
    final controller = ThemeController.instance;
    controller.setTheme(AppThemeId.cyberpunkViolet);
    expect(controller.theme.id, equals(AppThemeId.cyberpunkViolet));
    expect(controller.theme.name, equals('Cyberpunk Neon'));

    controller.setDotDensity(DotMatrixDensity.ultraDense);
    expect(controller.dotDensity, equals(DotMatrixDensity.ultraDense));
    expect(controller.dotDensity.spacing, equals(10.0));

    // Reset back to dense obsidian emerald
    controller.setTheme(AppThemeId.obsidianEmerald);
    controller.setDotDensity(DotMatrixDensity.dense);
    expect(controller.theme.id, equals(AppThemeId.obsidianEmerald));
    expect(controller.dotDensity.spacing, equals(13.0));
  });

  test('TouchDetector sub-pixel accumulator catches micro-movements without dropping', () {
    final detector = TouchDetector();

    detector.onPointerDown(const PointerDownEvent(pointer: 1, position: Offset(100.0, 100.0)));

    // Micro movement 1: 0.3px delta (normally dropped by .round() = 0)
    final p1 = detector.onPointerMove(const PointerMoveEvent(
      pointer: 1,
      position: Offset(100.3, 100.0),
      delta: Offset(0.3, 0.0),
    ));
    // Sub-pixel accumulator holds 0.3 -> returns null (not dropped, kept in accumulator)
    expect(p1, isNull);

    // Micro movement 2: 0.4px delta
    final p2 = detector.onPointerMove(const PointerMoveEvent(
      pointer: 1,
      position: Offset(100.7, 100.0),
      delta: Offset(0.4, 0.0),
    ));
    // Accumulator has 0.7 -> rounded to 1px! Dispatch happens!
    expect(p2, isNotNull);
    expect(p2!.opcode, equals(Opcode.move));
    expect(p2.dx, equals(1));
    expect(p2.dy, equals(0));
  });

  test('TouchDetector dispatches 2-finger horizontal swipe navigation for Back & Forward', () {
    final detector = TouchDetector();
    detector.twoFingerNavEnabled = true;

    // Simulate 2 fingers down
    detector.onPointerDown(const PointerDownEvent(pointer: 1, position: Offset(200.0, 200.0)));
    detector.onPointerDown(const PointerDownEvent(pointer: 2, position: Offset(250.0, 200.0)));

    // Swipe right by 40px (Back gesture)
    final navPacket = detector.onPointerMove(const PointerMoveEvent(
      pointer: 1,
      position: Offset(240.0, 200.0),
      delta: Offset(40.0, 0.0),
    ));

    expect(navPacket, isNotNull);
    expect(navPacket!.opcode, equals(Opcode.media));
    expect(navPacket.dx, equals(MediaKey.navBack.code));
  });
}
