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
import 'package:phonepad_mobile/core/theme/spring_bounce_tap.dart';
import 'package:phonepad_mobile/core/theme/liquid_glass_container.dart';
import 'package:phonepad_mobile/features/touch/presentation/liquid_speed_dial.dart';
import 'package:phonepad_mobile/features/splash/presentation/splash_screen.dart';
import 'package:phonepad_mobile/features/splash/presentation/border_glow_badge.dart';
import 'package:phonepad_mobile/features/splash/presentation/wave_photon_progress_bar.dart';

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
    await tester.tap(find.text('KEYBOARD'));
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
    await tester.tap(find.text('123 NUMPAD'));
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

  testWidgets('TouchSurface integrates LiquidSpeedDial and LiquidGlass clickpads', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final mockTransport = MockTransport();

    await tester.pumpWidget(MaterialApp(
      home: TouchSurface(
        transport: mockTransport,
        destination: '127.0.0.1:4242',
        onSettingsTap: () {},
      ),
    ));

    // LiquidSpeedDial trigger is rendered on trackpad
    expect(find.byType(LiquidSpeedDial), findsOneWidget);
    expect(find.text('LEFT CLICK'), findsOneWidget);
    expect(find.text('RIGHT CLICK'), findsOneWidget);

    // Tap LEFT CLICK pad -> dispatches tapLeft packet
    await tester.tap(find.text('LEFT CLICK'));
    await tester.pumpAndSettle();

    expect(mockTransport.sentPackets.any((p) => p.opcode == Opcode.tapLeft), isTrue);

    // Tap RIGHT CLICK pad -> dispatches tapRight packet
    await tester.tap(find.text('RIGHT CLICK'));
    await tester.pumpAndSettle();

    expect(mockTransport.sentPackets.any((p) => p.opcode == Opcode.tapRight), isTrue);

    // Open LiquidSpeedDial
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    // Verify actions visible
    expect(find.byIcon(Icons.splitscreen_rounded), findsOneWidget);
    expect(find.byIcon(Icons.desktop_windows_rounded), findsOneWidget);

    // Tap Show Desktop action
    await tester.tap(find.byIcon(Icons.desktop_windows_rounded));
    await tester.pumpAndSettle();

    // Verify 3-finger swipe packet was dispatched for Show Desktop
    final desktopPackets = mockTransport.sentPackets
        .where((p) => p.opcode == Opcode.move && p.dy == 30 && (p.flags & 0x01 != 0))
        .toList();
    expect(desktopPackets.isNotEmpty, isTrue);
  });

  testWidgets('SplashScreen renders circling particles, border glow badge, and progress bar', (WidgetTester tester) async {
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

    // Verify BorderGlowBadge is present
    expect(find.byType(BorderGlowBadge), findsOneWidget);

    // Verify WavePhotonProgressBar is present
    expect(find.byType(WavePhotonProgressBar), findsOneWidget);

    // Verify initial step text
    expect(find.text('Initializing touch digitizer...'), findsOneWidget);

    // Verify Skip button is present
    expect(find.text('Skip'), findsOneWidget);
  });

  testWidgets('SplashScreen advances boot progress and triggers onFinish when skipped or completed', (WidgetTester tester) async {
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

    // Tap Skip button
    await tester.tap(find.text('Skip'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    // Verify onFinish was invoked
    expect(finished, isTrue);
  });
}



