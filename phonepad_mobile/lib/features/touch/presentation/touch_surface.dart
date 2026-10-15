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
    this.initialMode = SurfaceMode.trackpad,
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
  bool _isHorizontalOrientation = false;

  ConnectionStatus _status = ConnectionStatus.disconnected;
  Timer? _heartbeatTimer;
  DateTime _lastPacketSent = DateTime.now();

  StreamSubscription<ConnectionStatus>? _statusSubscription;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
    _detector.highResMode = true; // 8x sub-pixel streaming for buttery smooth cursor tracking
    _detector.pinchZoomEnabled = ThemeController.instance.pinchZoomEnabled;
    _detector.rotateCoordinates = _isHorizontalOrientation;
    _detector.onEdgeScroll = _dispatchPacket;
    _detector.onInertialScroll = _dispatchPacket;
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
    _detector.dispose();
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

        final isKeyboardScreen = _currentMode == SurfaceMode.keyboard;

        return Scaffold(
          backgroundColor: theme.isDark ? Colors.black : theme.backgroundPrimary,
          body: SafeArea(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _buildBody(theme, isKeyboardScreen),
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

  /// Adaptive layout: Header is always on TOP for both Vertical and Horizontal modes.
  /// When horizontal mode is active, icons rotate 90 degrees and touch coordinates rotate 90 degrees.
  Widget _buildBody(PhonePadThemeData theme, bool isKeyboardScreen) {
    if (isKeyboardScreen) {
      // Full screen for Keyboard mode without top header
      return _buildSurfaceContent(theme);
    }

    // Both Vertical and Horizontal modes keep header on TOP
    return Column(
      children: [
        _buildTopHeader(theme),
        const SizedBox(height: 8),
        Expanded(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: _powerGovernor.isDimmed ? 0.05 : 1.0,
            child: _buildSurfaceContent(theme),
          ),
        ),
      ],
    );
  }

  /// Sleek header on TOP for both Vertical and Horizontal modes
  Widget _buildTopHeader(PhonePadThemeData theme) {
    Color statusColor;
    IconData statusIcon;

    switch (_status) {
      case ConnectionStatus.connected:
        statusColor = PhonePadColors.successGreen;
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

    final turns = _isHorizontalOrientation ? 1 : 0;

    return LiquidGlassContainer(
      height: 52,
      blur: 24.0,
      borderRadius: BorderRadius.circular(18),
      backgroundColor: theme.isDark
          ? const Color(0xFF07090E).withValues(alpha: 0.95)
          : theme.backgroundSecondary.withValues(alpha: 0.90),
      borderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          theme.accentPrimary.withValues(alpha: 0.70),
          theme.accentSecondary.withValues(alpha: 0.45),
          theme.accentPrimary.withValues(alpha: 0.35),
        ],
      ),
      borderWidth: 1.3,
      shadows: [
        BoxShadow(
          color: theme.accentPrimary.withValues(alpha: 0.18),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.6),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: [
          // Connection Status Pill
          SpringBounceTap(
            onTap: widget.onSettingsTap,
            child: Tooltip(
              message: _status == ConnectionStatus.connected ? 'Connected' : 'Connection Hub',
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: statusColor.withValues(alpha: 0.12),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.35),
                    width: 1.0,
                  ),
                ),
                child: Center(
                  child: RotatedBox(
                    quarterTurns: turns,
                    child: Icon(statusIcon, color: statusColor, size: 19),
                  ),
                ),
              ),
            ),
          ),

          const Spacer(),

          // Mode Selector Pills
          ...SurfaceMode.values.map((mode) {
            final isSelected = mode == _currentMode;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
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
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                theme.accentPrimary.withValues(alpha: 0.28),
                                theme.accentPrimary.withValues(alpha: 0.14),
                              ],
                            )
                          : null,
                      color: isSelected ? null : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? theme.accentPrimary.withValues(alpha: 0.55)
                            : Colors.transparent,
                        width: 1.0,
                      ),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: theme.accentPrimary.withValues(alpha: 0.20),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                      ],
                    ),
                    child: Center(
                      child: RotatedBox(
                        quarterTurns: turns,
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
              ),
            );
          }),

          const Spacer(),

          // Orientation Functionality Toggle (Hidden in Remote mode as it uses sensor orientation)
          if (_currentMode != SurfaceMode.remote) ...[
            SpringBounceTap(
              key: const Key('orientation_toggle_btn'),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _isHorizontalOrientation = !_isHorizontalOrientation;
                  _detector.rotateCoordinates = _isHorizontalOrientation;
                });
                _powerGovernor.recordActivity();
              },
              child: Tooltip(
                message: _isHorizontalOrientation ? 'Switch to Vertical Mode' : 'Switch to Horizontal Mode',
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: _isHorizontalOrientation
                        ? theme.accentPrimary.withValues(alpha: 0.18)
                        : (theme.isDark ? const Color(0xFF10121A) : theme.surfaceCard).withValues(alpha: 0.7),
                    border: Border.all(
                      color: _isHorizontalOrientation
                          ? theme.accentPrimary.withValues(alpha: 0.55)
                          : Colors.white.withValues(alpha: 0.07),
                      width: 1.0,
                    ),
                  ),
                  child: Center(
                    child: RotatedBox(
                      quarterTurns: turns,
                      child: Icon(
                        _isHorizontalOrientation
                            ? Icons.stay_current_landscape_rounded
                            : Icons.stay_current_portrait_rounded,
                        size: 20,
                        color: _isHorizontalOrientation
                            ? theme.accentPrimary
                            : theme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],

          // Settings Cog Icon
          SpringBounceTap(
            onTap: widget.onSettingsTap,
            child: Tooltip(
              message: 'Settings',
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (theme.isDark ? const Color(0xFF10121A) : theme.surfaceCard).withValues(alpha: 0.7),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.07),
                    width: 1.0,
                  ),
                ),
                child: Center(
                  child: RotatedBox(
                    quarterTurns: turns,
                    child: Icon(
                      Icons.tune_rounded,
                      size: 18,
                      color: theme.textSecondary,
                    ),
                  ),
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
        // Always in horizontal (widescreen) mode across full long screen dimension
        return RotatedBox(
          quarterTurns: 1,
          child: NumpadSurface(
            transport: widget.transport,
            onActivity: _powerGovernor.recordActivity,
            currentMode: _currentMode,
            onModeChanged: (mode) {
              setState(() {
                _currentMode = mode;
              });
              _powerGovernor.recordActivity();
            },
            onSettingsTap: widget.onSettingsTap,
            connectionStatus: _status,
          ),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        _detector.surfaceSize = Size(constraints.maxWidth, constraints.maxHeight);
        return Container(
          decoration: BoxDecoration(
            color: theme.isDark ? Colors.black : theme.backgroundSecondary,
            borderRadius: BorderRadius.circular(22),
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
                  final packet = _detector.onPointerDown(event);
                  _dispatchPacket(packet);
                  _touchNotifier.value++;
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
                },
                onPointerCancel: (event) {
                  _powerGovernor.recordActivity();
                  final packet = _detector.onPointerCancel(event);
                  _dispatchPacket(packet);
                  _touchNotifier.value++;
                },
                child: CustomPaint(
                  painter: SamsungDotMatrixPainter(
                    activePointers: _detector.activePointers,
                    repaint: _touchNotifier,
                    theme: theme,
                    dotSpacing: density.spacing,
                    baseDotRadius: density.baseRadius,
                    maxDotRadius: density.maxRadius,
                    containerBorderRadius: 22.0,
                  ),
                  child: Stack(
                    children: [
                      // Center Helper / Connect Banner (scoped repaint without widget tree rebuilds)
                      ValueListenableBuilder<int>(
                        valueListenable: _touchNotifier,
                        builder: (context, _, __) {
                          if (_detector.pointerCount > 0) {
                            return const SizedBox.shrink();
                          }
                          return Center(
                            child: RotatedBox(
                              quarterTurns: _isHorizontalOrientation ? 1 : 0,
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
                                        _isHorizontalOrientation
                                            ? 'HORIZONTAL TRACKPAD MODE\nSWIPE LEFT/RIGHT • 2-FINGER SCROLL'
                                            : 'PRECISION TRACKPAD SURFACE\n1-FINGER DRAG • 2-FINGER SCROLL & NAV • 3-FINGER SWITCH',
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
                          );
                        },
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
      },
    );
  }
}
