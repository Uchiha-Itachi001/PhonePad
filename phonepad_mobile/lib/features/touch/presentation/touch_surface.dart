import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/network/transport.dart';
import '../../../core/power/power_governor.dart';
import '../../../core/protocol/opcode.dart';
import '../../../core/protocol/packet.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_controller.dart';
import '../../modes/models/surface_mode.dart';
import '../../modes/presentation/mode_selector.dart';
import '../../modes/presentation/numpad_surface.dart';
import '../../modes/presentation/remote_surface.dart';
import '../logic/touch_detector.dart';
import 'samsung_dot_matrix_painter.dart';
import 'status_bar.dart';

class TouchSurface extends StatefulWidget {
  final ITransport transport;
  final String destination;
  final VoidCallback onSettingsTap;
  final PowerGovernor? powerGovernor;

  const TouchSurface({
    super.key,
    required this.transport,
    required this.destination,
    required this.onSettingsTap,
    this.powerGovernor,
  });

  @override
  State<TouchSurface> createState() => _TouchSurfaceState();
}

class _TouchSurfaceState extends State<TouchSurface> {
  final TouchDetector _detector = TouchDetector();
  final ValueNotifier<int> _touchNotifier = ValueNotifier<int>(0);
  late final PowerGovernor _powerGovernor;
  late final bool _ownsGovernor;
  SurfaceMode _currentMode = SurfaceMode.trackpad;

  ConnectionStatus _status = ConnectionStatus.disconnected;
  Timer? _heartbeatTimer;
  DateTime _lastPacketSent = DateTime.now();

  @override
  void initState() {
    super.initState();
    _status = widget.transport.status;
    _ownsGovernor = widget.powerGovernor == null;
    _powerGovernor = widget.powerGovernor ?? PowerGovernor();

    _powerGovernor.addListener(_onPowerGovernorChange);

    widget.transport.statusStream.listen((newStatus) {
      if (mounted) {
        setState(() {
          _status = newStatus;
        });
      }
    });

    // Send keep-alive heartbeat probe every 1000ms during idle periods
    _heartbeatTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      if (_status == ConnectionStatus.connected &&
          DateTime.now().difference(_lastPacketSent).inMilliseconds >= 1000) {
        widget.transport.sendPacket(const PhonePadPacket(opcode: Opcode.heartbeat));
        _lastPacketSent = DateTime.now();
      }
    });
  }

  void _onPowerGovernorChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _touchNotifier.dispose();
    _powerGovernor.removeListener(_onPowerGovernorChange);
    if (_ownsGovernor) {
      _powerGovernor.dispose();
    }
    super.dispose();
  }

  void _toggleOrientation(bool isLandscape) {
    if (isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  void _dispatchPacket(PhonePadPacket? packet) {
    if (packet != null) {
      widget.transport.sendPacket(packet);
      _lastPacketSent = DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final theme = ThemeController.instance.theme;
        _detector.twoFingerNavEnabled = ThemeController.instance.twoFingerNavEnabled;

        return Scaffold(
          backgroundColor: theme.backgroundPrimary,
          body: SafeArea(
            child: OrientationBuilder(
              builder: (context, orientation) {
                final isLandscape = orientation == Orientation.landscape;

                return Stack(
                  children: [
                    Column(
                      children: [
                        if (isLandscape) ...[
                          // Landscape Compact Top Bar (Status + Mode selector side by side)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: PhonePadStatusBar(
                                    status: _status,
                                    destination: widget.destination,
                                    pointerCount: _detector.pointerCount,
                                    onSettingsTap: widget.onSettingsTap,
                                    onToggleOrientation: () => _toggleOrientation(isLandscape),
                                    isLandscape: true,
                                    margin: EdgeInsets.zero,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ModeSelector(
                                  currentMode: _currentMode,
                                  onModeChanged: (mode) {
                                    setState(() {
                                      _currentMode = mode;
                                    });
                                    _powerGovernor.recordActivity();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // Portrait Top Status Bar
                          PhonePadStatusBar(
                            status: _status,
                            destination: widget.destination,
                            pointerCount: _detector.pointerCount,
                            onSettingsTap: widget.onSettingsTap,
                            onToggleOrientation: () => _toggleOrientation(isLandscape),
                            isLandscape: false,
                          ),

                          // Portrait Mode Selector Bar
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                            child: ModeSelector(
                              currentMode: _currentMode,
                              onModeChanged: (mode) {
                                setState(() {
                                  _currentMode = mode;
                                });
                                _powerGovernor.recordActivity();
                              },
                            ),
                          ),
                        ],

                        // Main Interactive Surface Area
                        Expanded(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 250),
                            opacity: _powerGovernor.isDimmed ? 0.05 : 1.0,
                            child: _buildSurfaceContent(isLandscape, theme),
                          ),
                        ),
                      ],
                    ),

                    // AMOLED Power Saver Tap-to-Wake Overlay
                    if (_powerGovernor.isDimmed)
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            _powerGovernor.recordActivity();
                          },
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.92),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.touch_app_rounded,
                                    color: theme.accentPrimary.withValues(alpha: 0.8),
                                    size: 40,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'AMOLED POWER SAVER',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      letterSpacing: 2.0,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tap anywhere to wake display in 0ms',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.5),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSurfaceContent(bool isLandscape, PhonePadThemeData theme) {
    switch (_currentMode) {
      case SurfaceMode.trackpad:
        return _buildTrackpadDigitizer(isLandscape, theme);
      case SurfaceMode.numpad:
        return NumpadSurface(
          transport: widget.transport,
          onActivity: _powerGovernor.recordActivity,
        );
      case SurfaceMode.remote:
        return RemoteSurface(
          transport: widget.transport,
          onActivity: _powerGovernor.recordActivity,
        );
    }
  }

  Widget _buildTrackpadDigitizer(bool isLandscape, PhonePadThemeData theme) {
    final density = ThemeController.instance.dotDensity;

    return Column(
      children: [
        // Main Trackpad Surface
        Expanded(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: isLandscape ? 12 : 16),
            decoration: BoxDecoration(
              color: theme.backgroundSecondary.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: _detector.pointerCount > 0
                    ? theme.accentPrimary.withValues(alpha: 0.45)
                    : theme.borderSubtle,
                width: 1.5,
              ),
              boxShadow: [
                if (_detector.pointerCount > 0)
                  BoxShadow(
                    color: theme.accentPrimary.withValues(alpha: 0.12),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) {
                  _powerGovernor.recordActivity();
                  HapticFeedback.selectionClick();
                  final packet = _detector.onPointerDown(event);
                  _dispatchPacket(packet);
                  _touchNotifier.value++;
                  setState(() {});
                },
                onPointerMove: (event) {
                  _powerGovernor.recordActivity();
                  final packet = _detector.onPointerMove(event);
                  _dispatchPacket(packet);
                  _touchNotifier.value++; // 120Hz zero-lag canvas repaint without widget tree rebuild!
                },
                onPointerUp: (event) {
                  _powerGovernor.recordActivity();
                  final packet = _detector.onPointerUp(event);
                  _dispatchPacket(packet);
                  _touchNotifier.value++;
                  setState(() {});
                },
                onPointerCancel: (event) {
                  _powerGovernor.recordActivity();
                  final packet = _detector.onPointerCancel(event);
                  _dispatchPacket(packet);
                  _touchNotifier.value++;
                  setState(() {});
                },
                child: CustomPaint(
                  painter: SamsungDotMatrixPainter(
                    activePointers: _detector.activePointers,
                    repaint: _touchNotifier,
                    theme: theme,
                    dotSpacing: density.spacing,
                    baseDotRadius: density.baseRadius,
                    maxDotRadius: density.maxRadius,
                  ),
                  child: Stack(
                    children: [
                      // Center Helper / Connect Banner
                      if (_detector.pointerCount == 0)
                        Center(
                          child: _status == ConnectionStatus.connected
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.touch_app_rounded,
                                      color: theme.textSecondary.withValues(alpha: 0.25),
                                      size: isLandscape ? 28 : 36,
                                    ),
                                    SizedBox(height: isLandscape ? 6 : 12),
                                    Text(
                                      'PRECISION TRACKPAD SURFACE\n1-FINGER DRAG • 2-FINGER SCROLL & NAV • 3-FINGER SWITCH',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: isLandscape ? 10 : 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.5,
                                        color: theme.textSecondary.withValues(alpha: 0.35),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(isLandscape ? 10 : 16),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: theme.accentPrimary.withValues(alpha: 0.1),
                                        border: Border.all(
                                          color: theme.accentPrimary.withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.wifi_tethering_rounded,
                                        color: theme.accentPrimary,
                                        size: isLandscape ? 24 : 32,
                                      ),
                                    ),
                                    SizedBox(height: isLandscape ? 8 : 16),
                                    Text(
                                      'NOT CONNECTED TO PC',
                                      style: TextStyle(
                                        color: theme.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                        fontSize: isLandscape ? 12 : 14,
                                      ),
                                    ),
                                    SizedBox(height: isLandscape ? 4 : 8),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: theme.accentPrimary,
                                        foregroundColor: Colors.black,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isLandscape ? 18 : 24,
                                          vertical: isLandscape ? 8 : 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        elevation: 8,
                                        shadowColor: theme.accentPrimary.withValues(alpha: 0.5),
                                      ),
                                      onPressed: widget.onSettingsTap,
                                      icon: const Icon(Icons.bolt_rounded, size: 20),
                                      label: const Text(
                                        'Connect PC Now',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Bottom Tactile Click Deck (Equal 50/50 Sizing & High-Grade Icons)
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isLandscape ? 12 : 16,
            vertical: isLandscape ? 6 : 10,
          ),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: _buildClickPad(
                  title: 'LEFT CLICK',
                  subtitle: 'PRIMARY',
                  icon: Icons.mouse_rounded,
                  theme: theme,
                  isLandscape: isLandscape,
                  isPrimary: true,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _dispatchPacket(const PhonePadPacket(opcode: Opcode.tapLeft));
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: _buildClickPad(
                  title: 'RIGHT CLICK',
                  subtitle: 'CONTEXT',
                  icon: Icons.menu_open_rounded,
                  theme: theme,
                  isLandscape: isLandscape,
                  isPrimary: false,
                  onTap: () {
                    HapticFeedback.heavyImpact();
                    _dispatchPacket(const PhonePadPacket(opcode: Opcode.tapRight));
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClickPad({
    required String title,
    required String subtitle,
    required IconData icon,
    required PhonePadThemeData theme,
    required bool isLandscape,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    final accent = isPrimary ? theme.accentPrimary : theme.accentSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: accent.withValues(alpha: 0.25),
        highlightColor: accent.withValues(alpha: 0.12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: isLandscape ? 8 : 12,
          ),
          decoration: BoxDecoration(
            color: theme.surfaceCard.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isPrimary
                  ? theme.accentPrimary.withValues(alpha: 0.35)
                  : theme.borderSubtle,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top glowing accent pill indicator
              Container(
                width: 24,
                height: 2.5,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.4),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              SizedBox(height: isLandscape ? 4 : 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 14, color: accent),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: theme.textSecondary.withValues(alpha: 0.7),
                          fontSize: 8.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
