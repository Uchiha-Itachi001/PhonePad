import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/network/transport.dart';
import '../../../core/power/power_governor.dart';
import '../../../core/protocol/opcode.dart';
import '../../../core/protocol/packet.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/liquid_glass_container.dart';
import '../../../core/theme/spring_bounce_tap.dart';
import '../../../core/theme/theme_controller.dart';
import '../../modes/models/surface_mode.dart';
import '../../modes/presentation/numpad_surface.dart';
import '../../modes/presentation/remote_surface.dart';
import '../logic/touch_detector.dart';
import 'samsung_dot_matrix_painter.dart';

class TouchSurface extends StatefulWidget {
  final ITransport transport;
  final String destination;
  final VoidCallback onSettingsTap;
  final PowerGovernor? powerGovernor;
  final SurfaceMode initialMode;

  const TouchSurface({
    super.key,
    required this.transport,
    required this.destination,
    required this.onSettingsTap,
    this.powerGovernor,
    this.initialMode = SurfaceMode.remote,
  });

  @override
  State<TouchSurface> createState() => _TouchSurfaceState();
}

class _TouchSurfaceState extends State<TouchSurface> {
  final TouchDetector _detector = TouchDetector();
  final ValueNotifier<int> _touchNotifier = ValueNotifier<int>(0);
  late final PowerGovernor _powerGovernor;
  late final bool _ownsGovernor;
  late SurfaceMode _currentMode;

  ConnectionStatus _status = ConnectionStatus.disconnected;
  Timer? _heartbeatTimer;
  DateTime _lastPacketSent = DateTime.now();

  StreamSubscription<ConnectionStatus>? _statusSubscription;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
    _detector.pinchZoomEnabled = ThemeController.instance.pinchZoomEnabled;
    _status = widget.transport.status;
    _ownsGovernor = false;
    _powerGovernor = widget.powerGovernor ?? PowerGovernor.instance;

    _powerGovernor.addListener(_onPowerGovernorChange);
    _subscribeToTransport();

    // Send keep-alive heartbeat probe every 1000ms during idle periods
    _heartbeatTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      if (_status == ConnectionStatus.connected &&
          DateTime.now().difference(_lastPacketSent).inMilliseconds >= 1000) {
        widget.transport.sendPacket(const PhonePadPacket(opcode: Opcode.heartbeat));
        _lastPacketSent = DateTime.now();
      }
    });
  }

  void _subscribeToTransport() {
    _statusSubscription = widget.transport.statusStream.listen((newStatus) {
      if (mounted) {
        setState(() {
          _status = newStatus;
        });
      }
    });
  }

  @override
  void didUpdateWidget(TouchSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transport != widget.transport) {
      _statusSubscription?.cancel();
      _status = widget.transport.status;
      _subscribeToTransport();
    }
  }

  void _onPowerGovernorChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _heartbeatTimer?.cancel();
    _touchNotifier.dispose();
    _powerGovernor.removeListener(_onPowerGovernorChange);
    if (_ownsGovernor) {
      _powerGovernor.dispose();
    }
    super.dispose();
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
        _detector.pinchZoomEnabled = ThemeController.instance.pinchZoomEnabled;

        return Scaffold(
          backgroundColor: theme.backgroundPrimary,
          body: SafeArea(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      // Sleek Left Dock: minimal horizontal space, icons only
                      _buildLeftRail(theme),
                      const SizedBox(width: 8),

                      // Main Interactive Surface Area (Full Widescreen Canvas)
                      Expanded(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 250),
                          opacity: _powerGovernor.isDimmed ? 0.05 : 1.0,
                          child: _buildSurfaceContent(theme),
                        ),
                      ),
                    ],
                  ),
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
            ),
          ),
        );
      },
    );
  }

  /// Sleek, minimal vertical icon-only navigation and status dock.
  Widget _buildLeftRail(PhonePadThemeData theme) {
    Color statusColor;
    IconData statusIcon;

    switch (_status) {
      case ConnectionStatus.connected:
        statusColor = theme.accentPrimary;
        statusIcon = Icons.wifi_rounded;
        break;
      case ConnectionStatus.connecting:
      case ConnectionStatus.reconnecting:
        statusColor = Colors.amber;
        statusIcon = Icons.wifi_find_rounded;
        break;
      case ConnectionStatus.disconnected:
        statusColor = PhonePadColors.errorRed;
        statusIcon = Icons.wifi_off_rounded;
        break;
    }

    return LiquidGlassContainer(
      width: 52,
      blur: 16.0,
      borderRadius: BorderRadius.circular(18),
      backgroundColor: theme.backgroundSecondary.withValues(alpha: 0.90),
      borderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: theme.isDark ? 0.20 : 0.5),
          theme.accentPrimary.withValues(alpha: 0.12),
          Colors.white.withValues(alpha: 0.04),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        children: [
          // Connection Status Icon (Icon only, no text)
          SpringBounceTap(
            onTap: widget.onSettingsTap,
            child: Tooltip(
              message: _status == ConnectionStatus.connected ? 'Connected' : 'Connection Hub',
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withValues(alpha: 0.15),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 20),
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withValues(alpha: 0.7),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: 24,
            height: 1,
            color: theme.borderSubtle,
          ),
          const SizedBox(height: 10),

          // Mode Selector Icons
          ...SurfaceMode.values.map((mode) {
            final isSelected = mode == _currentMode;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: SpringBounceTap(
                pressedScale: 0.90,
                bounceOvershoot: 1.06,
                onTap: () {
                  if (!isSelected) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _currentMode = mode;
                    });
                    _powerGovernor.recordActivity();
                  }
                },
                child: Tooltip(
                  message: mode.title,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                theme.accentPrimary.withValues(alpha: 0.35),
                                theme.accentSecondary.withValues(alpha: 0.20),
                              ],
                            )
                          : null,
                      color: isSelected ? null : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? theme.accentPrimary.withValues(alpha: 0.7)
                            : Colors.transparent,
                        width: 1.2,
                      ),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: theme.accentPrimary.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        mode.icon,
                        size: 20,
                        color: isSelected
                            ? theme.accentPrimary
                            : theme.textSecondary.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),

          const Spacer(),

          // Settings Cog Icon
          SpringBounceTap(
            onTap: widget.onSettingsTap,
            child: Tooltip(
              message: 'Settings',
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.surfaceCard.withValues(alpha: 0.6),
                  border: Border.all(color: theme.borderSubtle),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: theme.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurfaceContent(PhonePadThemeData theme) {
    switch (_currentMode) {
      case SurfaceMode.trackpad:
        return _buildTrackpadDigitizer(theme);
      case SurfaceMode.keyboard:
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

  /// Clean, crisp trackpad surface without blue glow, speed dial, or portrait click pads.
  Widget _buildTrackpadDigitizer(PhonePadThemeData theme) {
    final density = ThemeController.instance.dotDensity;

    return Container(
      decoration: BoxDecoration(
        color: theme.backgroundSecondary.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.borderSubtle,
          width: 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned.fill(
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
                  _touchNotifier.value++; // 120Hz zero-lag canvas repaint
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
                                      color: theme.textSecondary.withValues(alpha: 0.2),
                                      size: 32,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'PRECISION TRACKPAD SURFACE\n1-FINGER DRAG • 2-FINGER SCROLL & NAV • 3-FINGER SWITCH',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.5,
                                        color: theme.textSecondary.withValues(alpha: 0.3),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
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
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'NOT CONNECTED TO PC',
                                      style: TextStyle(
                                        color: theme.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: theme.accentPrimary,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 10,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        elevation: 6,
                                      ),
                                      onPressed: widget.onSettingsTap,
                                      icon: const Icon(Icons.bolt_rounded, size: 18),
                                      label: const Text(
                                        'Connect PC Now',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
          ],
        ),
      ),
    );
  }
}
