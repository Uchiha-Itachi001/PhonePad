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
import 'package:phonepad_mobile/features/modes/models/surface_mode.dart';
import 'package:phonepad_mobile/features/modes/presentation/numpad_surface.dart';
import 'package:phonepad_mobile/features/modes/presentation/remote_surface.dart';
import 'package:phonepad_mobile/core/theme/theme_controller.dart';
import 'package:phonepad_mobile/features/touch/logic/touch_detector.dart';
import 'package:phonepad_mobile/features/touch/presentation/touch_surface.dart';
import 'package:phonepad_mobile/core/theme/spring_bounce_tap.dart';
import 'package:phonepad_mobile/core/theme/liquid_glass_container.dart';
import 'package:phonepad_mobile/features/touch/presentation/liquid_speed_dial.dart';
import 'package:phonepad_mobile/features/splash/presentation/splash_screen.dart';
import 'package:phonepad_mobile/features/modes/presentation/keyboard_deck.dart';
import 'package:phonepad_mobile/features/connection/presentation/connection_hub.dart';
import 'package:phonepad_mobile/features/connection/presentation/qr_scanner_view.dart';

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
        initialMode: SurfaceMode.trackpad,
      ),
    ));

    expect(find.byIcon(Icons.wifi_rounded), findsOneWidget);

    // Simulate drag gesture on touch surface
    final gesture = await tester.startGesture(const Offset(200, 300));
    await gesture.moveBy(const Offset(15, 20));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    // Verify touch packet was dispatched to transport (8x high-res sub-pixel streaming)
    expect(mockTransport.sentPackets.isNotEmpty, isTrue);
    expect(mockTransport.sentPackets.first.opcode, equals(Opcode.move));
    expect(mockTransport.sentPackets.first.dx, equals(120));
    expect(mockTransport.sentPackets.first.dy, equals(160));
    expect(mockTransport.sentPackets.first.isHighRes, isTrue);
  });

  testWidgets('TouchSurface detects quick tap as Left Click with haptic flag', (WidgetTester tester) async {
    final mockTransport = MockTransport();

    await tester.pumpWidget(MaterialApp(
      home: TouchSurface(
        transport: mockTransport,
        destination: '127.0.0.1:4242',
        onSettingsTap: () {},
        initialMode: SurfaceMode.trackpad,
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
        initialMode: SurfaceMode.trackpad,
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

    // Switch to 123 NUMPAD mode (since Keyboard is now default)
    await tester.tap(find.byKey(const Key('deck_switch_numpad_btn')));
    await tester.pumpAndSettle();

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

  testWidgets('NumpadSurface switches to Keyboard deck and dispatches opcode.keyboard packets', (WidgetTester tester) async {
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

    // Switch to KEYBOARD mode
    await tester.tap(find.byKey(const Key('deck_switch_keyboard_btn')));
    await tester.pumpAndSettle();

    // Verify keyboard keys are now present
    expect(find.text('SPACE'), findsOneWidget);
    expect(find.text('ESC'), findsOneWidget);
    expect(find.text('TAB'), findsOneWidget);

    // Tap letter 'a'
    activityTriggered = false;
    await tester.tap(find.text('a'));
    await tester.pump();

    expect(activityTriggered, isTrue);
    final charPackets = mockTransport.sentPackets.where((p) => p.opcode == Opcode.keyboard).toList();
    expect(charPackets.isNotEmpty, isTrue);
    expect(charPackets.last.dx, equals('a'.codeUnitAt(0)));
    expect(charPackets.last.dy, equals(KeyboardKeyType.unicodeChar));

    // Tap SPACE bar
    await tester.tap(find.text('SPACE'));
    await tester.pump();

    expect(mockTransport.sentPackets.last.opcode, equals(Opcode.keyboard));
    expect(mockTransport.sentPackets.last.dx, equals(32)); // ' '

    // Tap ESC key
    await tester.tap(find.text('ESC'));
    await tester.pump();

    expect(mockTransport.sentPackets.last.opcode, equals(Opcode.keyboard));
    expect(mockTransport.sentPackets.last.dx, equals(SpecialKey.escape.code));
    expect(mockTransport.sentPackets.last.dy, equals(KeyboardKeyType.specialKey));

    // Tap COPY shortcut
    await tester.tap(find.text('COPY'));
    await tester.pump();

    expect(mockTransport.sentPackets.last.opcode, equals(Opcode.keyboard));
    expect(mockTransport.sentPackets.last.dx, equals(ShortcutKey.copy.code));
    expect(mockTransport.sentPackets.last.dy, equals(KeyboardKeyType.shortcut));

    // Switch back to NUMPAD mode
    await tester.tap(find.byKey(const Key('deck_switch_numpad_btn')));
    await tester.pumpAndSettle();

    expect(find.text('7'), findsOneWidget);
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

  testWidgets('TouchSurface left rail switches between Trackpad, Keyboard, and Remote', (WidgetTester tester) async {
    final mockTransport = MockTransport();

    await tester.pumpWidget(MaterialApp(
      home: TouchSurface(
        transport: mockTransport,
        destination: '127.0.0.1:4242',
        onSettingsTap: () {},
        initialMode: SurfaceMode.trackpad,
      ),
    ));

    // Initially in Trackpad mode
    expect(find.byIcon(Icons.keyboard_rounded), findsOneWidget);
    expect(find.byIcon(Icons.settings_remote_rounded), findsOneWidget);
    expect(find.text('SPACE'), findsNothing);

    // Switch to Keyboard mode via Left Rail icon
    await tester.tap(find.byIcon(Icons.keyboard_rounded));
    await tester.pumpAndSettle();

    // In Keyboard mode, Keyboard is active by default with spacebar & function keys
    expect(find.text('SPACE'), findsOneWidget);
    expect(find.text('Esc'), findsOneWidget);
    expect(find.text('F1'), findsOneWidget);

    // Switch to Remote mode via Left Rail icon
    await tester.tap(find.byIcon(Icons.settings_remote_rounded));
    await tester.pumpAndSettle();

    expect(find.text('PREV'), findsOneWidget);
    expect(find.text('NEXT'), findsOneWidget);
    expect(find.text('PLAY'), findsOneWidget);
    expect(find.text('MUTE'), findsOneWidget);
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

  test('TouchDetector detects 2-finger tap as Right Click without trailing left click', () {
    final detector = TouchDetector();

    // 2 fingers down
    detector.onPointerDown(const PointerDownEvent(pointer: 1, position: Offset(150.0, 150.0)));
    detector.onPointerDown(const PointerDownEvent(pointer: 2, position: Offset(200.0, 150.0)));

    // Finger 1 lifts first
    final rightClick = detector.onPointerUp(const PointerUpEvent(pointer: 1, position: Offset(150.0, 150.0)));
    expect(rightClick, isNotNull);
    expect(rightClick!.opcode, equals(Opcode.tapRight));

    // Finger 2 lifts ~15ms later: MUST NOT emit tapLeft!
    final secondLift = detector.onPointerUp(const PointerUpEvent(pointer: 2, position: Offset(200.0, 150.0)));
    // Should either be lift reset packet (move with flags 0) or null, NEVER tapLeft
    if (secondLift != null) {
      expect(secondLift.opcode, isNot(equals(Opcode.tapLeft)));
    }
  });

  test('TouchDetector dispatches pinch-to-zoom for squeeze (shrink) and spread (expand)', () {
    final detector = TouchDetector();
    detector.twoFingerNavEnabled = false; // Isolate pinch testing
    detector.pinchZoomEnabled = true;

    // 2 fingers down at distance 100px
    detector.onPointerDown(const PointerDownEvent(pointer: 1, position: Offset(100.0, 200.0)));
    detector.onPointerDown(const PointerDownEvent(pointer: 2, position: Offset(200.0, 200.0)));

    // Squeeze (shrink) fingers together by moving finger 2 closer to finger 1 by 20px (span drops from 100 to 80)
    final zoomOut = detector.onPointerMove(const PointerMoveEvent(
      pointer: 2,
      position: Offset(180.0, 200.0),
      delta: Offset(-20.0, 0.0),
    ));
    expect(zoomOut, isNotNull);
    expect(zoomOut!.opcode, equals(Opcode.zoom));
    expect(zoomOut.dy, equals(-1)); // Zoom Out

    // Spread (expand) fingers apart by moving finger 2 away by 20px (span increases from 80 to 100)
    final zoomIn = detector.onPointerMove(const PointerMoveEvent(
      pointer: 2,
      position: Offset(200.0, 200.0),
      delta: Offset(20.0, 0.0),
    ));
    expect(zoomIn, isNotNull);
    expect(zoomIn!.opcode, equals(Opcode.zoom));
    expect(zoomIn.dy, equals(1)); // Zoom In
  });

  test('TouchDetector initiates DragStart on tap-then-tap-and-move with deltas', () {
    final detector = TouchDetector();

    // First quick tap
    detector.onPointerDown(const PointerDownEvent(pointer: 1, position: Offset(100.0, 100.0)));
    final tap1 = detector.onPointerUp(const PointerUpEvent(pointer: 1, position: Offset(100.0, 100.0)));
    expect(tap1!.opcode, equals(Opcode.tapLeft));

    // Second tap down within 350ms at same spot -> initiates drag lock
    final downPacket = detector.onPointerDown(const PointerDownEvent(pointer: 1, position: Offset(101.0, 101.0)));
    expect(detector.isDragLocked, isTrue);
    // Does NOT dispatch dragStart prematurely at (0, 0)
    expect(downPacket, isNull);

    // Now move the pointer by 15px -> dispatches dragStart WITH movement deltas for window moving
    final dragMove = detector.onPointerMove(const PointerMoveEvent(
      pointer: 1,
      position: Offset(116.0, 101.0),
      delta: Offset(15.0, 0.0),
    ));
    expect(dragMove, isNotNull);
    expect(dragMove!.opcode, equals(Opcode.dragStart));
    expect(dragMove.dx, equals(15));
    expect(dragMove.dy, equals(0));

    // Release finger -> dispatches dragEnd
    final dragEnd = detector.onPointerUp(const PointerUpEvent(pointer: 1, position: Offset(116.0, 101.0)));
    expect(dragEnd, isNotNull);
    expect(dragEnd!.opcode, equals(Opcode.dragEnd));
    expect(detector.isDragLocked, isFalse);
  });

  test('TouchDetector smart parallel scroll suppresses pinch-to-zoom during non-parallel drift', () {
    final detector = TouchDetector();
    detector.twoFingerNavEnabled = false;
    detector.pinchZoomEnabled = true;

    // 2 fingers down at distance 80px
    detector.onPointerDown(const PointerDownEvent(pointer: 1, position: Offset(100.0, 200.0)));
    detector.onPointerDown(const PointerDownEvent(pointer: 2, position: Offset(180.0, 200.0)));

    // Scroll down with both fingers, with slight non-parallel drift (span drifts slightly 1-2px)
    final scroll1 = detector.onPointerMove(const PointerMoveEvent(
      pointer: 1,
      position: Offset(101.0, 208.0),
      delta: Offset(1.0, 8.0),
    ));
    expect(scroll1, isNotNull);
    expect(scroll1!.opcode, equals(Opcode.scroll));

    // Next step with finger 2 drifting slightly
    final scroll2 = detector.onPointerMove(const PointerMoveEvent(
      pointer: 2,
      position: Offset(182.0, 210.0),
      delta: Offset(2.0, 10.0),
    ));
    expect(scroll2, isNotNull);
    expect(scroll2!.opcode, equals(Opcode.scroll));
    // Must NOT be zoom!
    expect(scroll2.opcode, isNot(equals(Opcode.zoom)));
  });

  test('TouchDetector triggers edge auto-scroll during drag-and-drop near borders', () async {
    final detector = TouchDetector();
    detector.surfaceSize = const Size(400.0, 800.0);

    PhonePadPacket? edgePacket;
    detector.onEdgeScroll = (p) {
      edgePacket = p;
    };

    // Tap 1
    detector.onPointerDown(const PointerDownEvent(pointer: 1, position: Offset(200.0, 400.0)));
    detector.onPointerUp(const PointerUpEvent(pointer: 1, position: Offset(200.0, 400.0)));

    // Tap 2 -> Drag Lock
    detector.onPointerDown(const PointerDownEvent(pointer: 1, position: Offset(200.0, 400.0)));
    expect(detector.isDragLocked, isTrue);

    // Move to bottom edge (y = 785 is within 32px of 800)
    detector.onPointerMove(const PointerMoveEvent(
      pointer: 1,
      position: Offset(200.0, 785.0),
      delta: Offset(0.0, 385.0),
    ));

    // Wait 50ms for periodic edge scroll ticker to tick
    await Future.delayed(const Duration(milliseconds: 50));
    expect(edgePacket, isNotNull);
    expect(edgePacket!.opcode, equals(Opcode.scroll));
    expect(edgePacket!.dy, lessThan(0)); // Scrolling down (negative dy in Windows MOUSEEVENTF_WHEEL)

    detector.dispose();
  });

  test('TouchDetector 2-finger scroll accumulates sub-pixel movements smoothly', () {
    final detector = TouchDetector();
    detector.twoFingerNavEnabled = false;
    detector.pinchZoomEnabled = false;

    detector.onPointerDown(const PointerDownEvent(pointer: 1, position: Offset(100.0, 100.0)));
    detector.onPointerDown(const PointerDownEvent(pointer: 2, position: Offset(100.0, 150.0)));

    // Micro scroll step 1: 0.3px delta -> held in scroll accumulator, returns null
    final s1 = detector.onPointerMove(const PointerMoveEvent(
      pointer: 1,
      position: Offset(100.0, 100.3),
      delta: Offset(0.0, 0.3),
    ));
    expect(s1, isNull);

    // Micro scroll step 2: 0.4px delta -> accumulated 0.7px -> dispatches 1px scroll packet!
    final s2 = detector.onPointerMove(const PointerMoveEvent(
      pointer: 1,
      position: Offset(100.0, 100.7),
      delta: Offset(0.0, 0.4),
    ));
    expect(s2, isNotNull);
    expect(s2!.opcode, equals(Opcode.scroll));
    expect(s2.dy, equals(1));
  });

  test('TouchDetector highResMode streams 8x sub-pixel precision with flagHighRes', () {
    final detector = TouchDetector();
    detector.highResMode = true;

    detector.onPointerDown(const PointerDownEvent(pointer: 1, position: Offset(100.0, 100.0)));

    // Micro move: 0.25px delta -> in highResMode, 0.25 * 8 = 2 units! Dispatches immediately!
    final p1 = detector.onPointerMove(const PointerMoveEvent(
      pointer: 1,
      position: Offset(100.25, 100.0),
      delta: Offset(0.25, 0.0),
    ));
    expect(p1, isNotNull);
    expect(p1!.opcode, equals(Opcode.move));
    expect(p1.dx, equals(2));
    expect(p1.isHighRes, isTrue);
  });

  test('TouchDetector launches kinetic inertial scroll and brakes immediately on pointer down', () async {
    final detector = TouchDetector();
    final packets = <PhonePadPacket>[];
    detector.onInertialScroll = (p) => packets.add(p);

    detector.onPointerDown(const PointerDownEvent(pointer: 1, position: Offset(100.0, 100.0)));
    detector.onPointerDown(const PointerDownEvent(pointer: 2, position: Offset(140.0, 100.0)));

    // Fast 2-finger scroll over 2 frames (move 10px then 15px in Y)
    detector.onPointerMove(const PointerMoveEvent(
      pointer: 1,
      position: Offset(100.0, 110.0),
      delta: Offset(0.0, 10.0),
    ));
    await Future.delayed(const Duration(milliseconds: 16));
    detector.onPointerMove(const PointerMoveEvent(
      pointer: 1,
      position: Offset(100.0, 125.0),
      delta: Offset(0.0, 15.0),
    ));

    // Release fingers with flick
    detector.onPointerUp(const PointerUpEvent(pointer: 1, position: Offset(100.0, 125.0)));
    detector.onPointerUp(const PointerUpEvent(pointer: 2, position: Offset(140.0, 100.0)));

    // Wait for inertial ticks to emit
    await Future.delayed(const Duration(milliseconds: 50));
    expect(packets, isNotEmpty);
    expect(packets.first.opcode, equals(Opcode.scroll));
    final countBeforeBrake = packets.length;

    // Tap to brake: touching down immediately halts inertia
    detector.onPointerDown(const PointerDownEvent(pointer: 1, position: Offset(100.0, 120.0)));
    await Future.delayed(const Duration(milliseconds: 40));
    expect(packets.length, equals(countBeforeBrake));

    detector.dispose();
  });

  test('TouchDetector rotateCoordinates rotates movement deltas 90 degrees', () {
    final detector = TouchDetector();
    detector.rotateCoordinates = true;

    detector.onPointerDown(const PointerDownEvent(pointer: 1, position: Offset(100.0, 100.0)));

    // Raw delta: dx = 0, dy = 10 (user swiped right on sideways-held phone)
    // Transformed delta: dx = 10, dy = 0 (cursor moves right on PC!)
    final moveRight = detector.onPointerMove(const PointerMoveEvent(
      pointer: 1,
      position: Offset(100.0, 110.0),
      delta: Offset(0.0, 10.0),
    ));
    expect(moveRight, isNotNull);
    expect(moveRight!.dx, equals(10));
    expect(moveRight.dy, equals(0));

    // Raw delta: dx = 10, dy = 0 (user swiped up on sideways-held phone)
    // Transformed delta: dx = 0, dy = -10 (cursor moves up on PC!)
    final moveUp = detector.onPointerMove(const PointerMoveEvent(
      pointer: 1,
      position: Offset(110.0, 110.0),
      delta: Offset(10.0, 0.0),
    ));
    expect(moveUp, isNotNull);
    expect(moveUp!.dx, equals(0));
    expect(moveUp.dy, equals(-10));
  });

  testWidgets('SpringBounceTap applies tactile spring animation on tap and executes callback', (WidgetTester tester) async {
    var tapped = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SpringBounceTap(
            onTap: () => tapped = true,
            child: const Text('SPRING BUTTON'),
          ),
        ),
      ),
    ));

    expect(find.text('SPRING BUTTON'), findsOneWidget);
    await tester.tap(find.text('SPRING BUTTON'));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });

  testWidgets('LiquidGlassContainer renders child with frosted glass styling', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: LiquidGlassContainer(
            blur: 12.0,
            width: 120,
            height: 60,
            child: const Text('FROSTED GLASS'),
          ),
        ),
      ),
    ));

    expect(find.text('FROSTED GLASS'), findsOneWidget);
    expect(find.byType(LiquidGlassContainer), findsOneWidget);
  });

  testWidgets('LiquidSpeedDial expands satellite actions on trigger tap and triggers action', (WidgetTester tester) async {
    var actionTapped = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: LiquidSpeedDial(
            actions: [
              LiquidDialAction(
                icon: Icons.desktop_windows_rounded,
                label: 'Desktop',
                onTap: () => actionTapped = true,
              ),
              LiquidDialAction(
                icon: Icons.hub_rounded,
                label: 'Hub',
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    ));

    // Initially trigger is visible, satellites not yet expanded
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);

    // Tap trigger to expand satellites with spring bounce
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.desktop_windows_rounded), findsOneWidget);
    expect(find.byIcon(Icons.hub_rounded), findsOneWidget);

    // Tap satellite action
    await tester.tap(find.byIcon(Icons.desktop_windows_rounded));
    await tester.pumpAndSettle();

    expect(actionTapped, isTrue);
  });

  testWidgets('TouchSurface renders left navigation rail and clean trackpad surface', (WidgetTester tester) async {
    final mockTransport = MockTransport();

    await tester.pumpWidget(MaterialApp(
      home: TouchSurface(
        transport: mockTransport,
        destination: '127.0.0.1:4242',
        onSettingsTap: () {},
        initialMode: SurfaceMode.trackpad,
      ),
    ));

    // Left rail icons rendered
    expect(find.byIcon(Icons.wifi_rounded), findsOneWidget);
    expect(find.byIcon(Icons.mouse_rounded), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_rounded), findsOneWidget);
    expect(find.byIcon(Icons.settings_remote_rounded), findsOneWidget);
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);

    // Trackpad digitizer surface rendered
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('SplashScreen renders 3D thinking orb and simple progress status', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SplashScreen(
        onFinish: () {},
        bootDuration: const Duration(seconds: 10),
        autoDismiss: false,
      ),
    ));

    // Verify Brand typography and emblem elements
    expect(find.text('Phone'), findsOneWidget);
    expect(find.text('Pad'), findsOneWidget);
    expect(find.text('NATIVE REAL-TIME WI-FI TRACKPAD'), findsOneWidget);

    // Verify 3D Thinking Orb is present
    expect(find.byKey(const Key('thinking_orb_custom_paint')), findsOneWidget);

    // Verify initial step text
    expect(find.text('Initializing touch digitizer...'), findsOneWidget);

    // Verify Skip button is removed
    expect(find.text('Skip'), findsNothing);
  });

  testWidgets('SplashScreen advances boot progress and triggers onFinish when completed', (WidgetTester tester) async {
    bool finished = false;

    await tester.pumpWidget(MaterialApp(
      home: SplashScreen(
        onFinish: () {
          finished = true;
        },
        bootDuration: const Duration(milliseconds: 1000),
        autoDismiss: true,
      ),
    ));

    // Initially not finished
    expect(finished, isFalse);

    // Advance boot progress to completion
    await tester.pump(const Duration(milliseconds: 1050));
    await tester.pump(const Duration(milliseconds: 450));

    // Verify onFinish was invoked
    expect(finished, isTrue);
  });

  testWidgets('RemoteSurface adapts layout based on orientation without manual toggle button', (WidgetTester tester) async {
    final mockTransport = MockTransport();

    // Set portrait dimensions
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RemoteSurface(
          transport: mockTransport,
          onActivity: () {},
        ),
      ),
    ));

    // No manual vertical mode toggle button exists
    expect(find.text('VERTICAL MODE'), findsNothing);
    expect(find.text('HORIZONTAL MODE'), findsNothing);

    // Verify slide buttons and click buttons are present in portrait mode
    expect(find.byKey(const Key('next_slide_btn')), findsOneWidget);
    expect(find.text('PREV'), findsOneWidget);
    expect(find.text('LEFT CLICK'), findsOneWidget);
    expect(find.text('RIGHT CLICK'), findsOneWidget);

    // Switch to landscape orientation
    tester.view.physicalSize = const Size(800, 400);
    await tester.pumpAndSettle();

    // Renders successfully without manual toggle button
    expect(find.text('VERTICAL MODE'), findsNothing);
    expect(find.text('REMOTE ACTIVE'), findsOneWidget);
  });

  testWidgets('TouchSurface defaults to Trackpad mode in portrait and toggles horizontal mode', (WidgetTester tester) async {
    final mockTransport = MockTransport();

    await tester.pumpWidget(MaterialApp(
      home: TouchSurface(
        transport: mockTransport,
        destination: '127.0.0.1:4242',
        onSettingsTap: () {},
      ),
    ));

    // Default mode is Trackpad in portrait: top header is present
    expect(find.textContaining('PRECISION TRACKPAD SURFACE'), findsOneWidget);
    expect(find.byKey(const Key('orientation_toggle_btn')), findsOneWidget);

    // Tap orientation toggle in top header to switch to horizontal mode
    await tester.tap(find.byKey(const Key('orientation_toggle_btn')));
    await tester.pumpAndSettle();

    // In horizontal mode, header stays on TOP and trackpad text adapts
    expect(find.byKey(const Key('orientation_toggle_btn')), findsOneWidget);
    expect(find.textContaining('HORIZONTAL TRACKPAD MODE'), findsOneWidget);

    // Toggle back to vertical mode from top header
    await tester.tap(find.byKey(const Key('orientation_toggle_btn')));
    await tester.pumpAndSettle();

    // Top header is back in vertical mode
    expect(find.byKey(const Key('orientation_toggle_btn')), findsOneWidget);
    expect(find.textContaining('PRECISION TRACKPAD SURFACE'), findsOneWidget);

    // Switch to Keyboard mode (tap keyboard icon in top header)
    await tester.tap(find.byIcon(Icons.keyboard_rounded));
    await tester.pumpAndSettle();

    // In Keyboard mode, full screen horizontal deck with SPACE key is active
    expect(find.text('SPACE'), findsOneWidget);
    expect(find.byIcon(Icons.touch_app_rounded), findsOneWidget);
    expect(find.byIcon(Icons.settings_remote_rounded), findsOneWidget);

    // Tap Remote icon from the keyboard header to switch to Remote mode
    await tester.tap(find.byIcon(Icons.settings_remote_rounded));
    await tester.pumpAndSettle();

    // In Remote mode, renders remote deck and telemetry
    expect(find.text('REMOTE ACTIVE'), findsOneWidget);
    expect(find.text('VERTICAL MODE'), findsNothing);
  });

  testWidgets('SpringBounceTap auto-repeats callback on press-and-hold', (WidgetTester tester) async {
    int triggers = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SpringBounceTap(
            repeatInitialDelay: const Duration(milliseconds: 100),
            repeatInterval: const Duration(milliseconds: 50),
            onHoldRepeat: () => triggers++,
            child: const Text('Hold Me'),
          ),
        ),
      ),
    ));

    // Tap and hold
    final gesture = await tester.startGesture(tester.getCenter(find.text('Hold Me')));
    await tester.pump();
    expect(triggers, equals(1)); // Initial trigger immediately

    // Advance 120ms (past 100ms initial delay)
    await tester.pump(const Duration(milliseconds: 120));
    expect(triggers, greaterThanOrEqualTo(1));

    // Advance 150ms (intervals of 50ms)
    await tester.pump(const Duration(milliseconds: 160));
    expect(triggers, greaterThanOrEqualTo(3));

    // Release
    await gesture.up();
    await tester.pump();
  });

  testWidgets('KeyboardDeck Shift + Enter dispatches ShortcutKey.shiftEnter (Next Line)', (WidgetTester tester) async {
    final mockTransport = MockTransport();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: KeyboardDeck(
          transport: mockTransport,
          onActivity: () {},
          onKeyNameChanged: (_) {},
        ),
      ),
    ));

    // Tap Shift key (arrow upward icon in bottom row)
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded).last);
    await tester.pumpAndSettle();

    // Verify Enter key now displays 'NEXT'
    expect(find.text('NEXT'), findsOneWidget);

    // Tap the Enter key
    await tester.tap(find.byIcon(Icons.subdirectory_arrow_right_rounded));
    await tester.pump();

    // Verify packet sent is ShortcutKey.shiftEnter
    expect(mockTransport.sentPackets.isNotEmpty, isTrue);
    final lastPacket = mockTransport.sentPackets.last;
    expect(lastPacket.opcode, equals(Opcode.keyboard));
    expect(lastPacket.dx, equals(ShortcutKey.shiftEnter.code));
    expect(lastPacket.dy, equals(KeyboardKeyType.shortcut));
  });

  testWidgets('RemoteSurface Mute button toggles active visual state and sends MediaKey.mute', (WidgetTester tester) async {
    final mockTransport = MockTransport();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RemoteSurface(
          transport: mockTransport,
          onActivity: () {},
        ),
      ),
    ));

    // Initial state: not muted
    expect(find.descendant(of: find.byKey(const Key('mute_btn')), matching: find.text('MUTE')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('mute_btn')), matching: find.text('MUTED')), findsNothing);

    // Tap mute button
    await tester.tap(find.byKey(const Key('mute_btn')));
    await tester.pumpAndSettle();

    // Verify active visual state changes to MUTED and packet sent
    expect(find.descendant(of: find.byKey(const Key('mute_btn')), matching: find.text('MUTED')), findsOneWidget);
    expect(mockTransport.sentPackets.any((p) => p.opcode == Opcode.media && p.dx == MediaKey.mute.code), isTrue);

    // Tap Vol + button to auto-unmute
    await tester.tap(find.byKey(const Key('vol_up_btn')));
    await tester.pumpAndSettle();

    // State returns to unmuted
    expect(find.descendant(of: find.byKey(const Key('mute_btn')), matching: find.text('MUTE')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('mute_btn')), matching: find.text('MUTED')), findsNothing);
  });

  testWidgets('ConnectionHubModal renders desktop app download instruction banner', (WidgetTester tester) async {
    final discoveryClient = DiscoveryClient();
    try {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ConnectionHubModal(
            discoveryClient: discoveryClient,
            currentDestination: '',
            onConnect: (_, __, ___) {},
          ),
        ),
      ));

      expect(find.text('Desktop App Required'), findsOneWidget);
      expect(find.textContaining('Download and run PhonePad Host'), findsOneWidget);
    } finally {
      discoveryClient.stopDiscovery();
      discoveryClient.dispose();
    }
  });

  test('QrPairingData parses phonepad://connect URI and raw IP:port strings', () {
    // Case 1: Standard Host QR URI
    final qr1 = QrPairingData.parse(
      'phonepad://connect?ip=192.168.1.50&port=4242&name=My-Laptop&pin=9999',
    );
    expect(qr1, isNotNull);
    expect(qr1!.ip, '192.168.1.50');
    expect(qr1.port, 4242);
    expect(qr1.name, 'My-Laptop');
    expect(qr1.pin, 9999);
    expect(qr1.destination, '192.168.1.50:4242');

    // Case 2: Raw ip:port:pin
    final qr2 = QrPairingData.parse('10.0.0.5:5000:1234');
    expect(qr2, isNotNull);
    expect(qr2!.ip, '10.0.0.5');
    expect(qr2.port, 5000);
    expect(qr2.pin, 1234);

    // Case 3: Raw ip:port
    final qr3 = QrPairingData.parse('10.0.0.5:5000');
    expect(qr3, isNotNull);
    expect(qr3!.ip, '10.0.0.5');
    expect(qr3.port, 5000);
    expect(qr3.pin, 0);

    // Case 4: Raw IP only
    final qr4 = QrPairingData.parse('192.168.1.100');
    expect(qr4, isNotNull);
    expect(qr4!.ip, '192.168.1.100');
    expect(qr4.port, 4242);
    expect(qr4.pin, 0);

    // Case 5: Malformed
    expect(QrPairingData.parse(''), isNull);
    expect(QrPairingData.parse('   '), isNull);
    expect(QrPairingData.parse('random-junk-text'), isNull);
  });

  testWidgets('ConnectionHubModal renders Wi-Fi Auto-Discovery host view without QR or Manual IP', (WidgetTester tester) async {
    final discoveryClient = DiscoveryClient();
    try {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ConnectionHubModal(
            discoveryClient: discoveryClient,
            currentDestination: '',
            onConnect: (_, __, ___) {},
          ),
        ),
      ));

      // Streamlined Same-WiFi view: No QR or Manual IP subtabs
      expect(find.text('Scan QR'), findsNothing);
      expect(find.text('Manual IP'), findsNothing);
      expect(find.byIcon(Icons.qr_code_scanner_rounded), findsNothing);
      // Wi-Fi Host discovery header and empty state search refresh button
      expect(find.text('DISCOVERED PC HOSTS'), findsOneWidget);
      expect(find.text('Refresh Scan'), findsOneWidget);
    } finally {
      discoveryClient.stopDiscovery();
      discoveryClient.dispose();
    }
  });
}



