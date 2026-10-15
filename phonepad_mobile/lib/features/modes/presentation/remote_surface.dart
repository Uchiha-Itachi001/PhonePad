import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/network/transport.dart';
import '../../../core/protocol/keys.dart';
import '../../../core/protocol/opcode.dart';
import '../../../core/protocol/packet.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spring_bounce_tap.dart';
import '../../../core/theme/theme_controller.dart';
import '../../touch/models/touch_point.dart';
import '../../touch/presentation/samsung_dot_matrix_painter.dart';

/// Legacy sub-deck enum retained for backwards compatibility.
enum RemoteDeckTab {
  remote('Remote', Icons.tv_rounded),
  airMouse('Air Mouse', Icons.near_me_rounded);

  final String label;
  final IconData icon;
  const RemoteDeckTab(this.label, this.icon);
}

/// Unified Air Mouse & Media Remote Surface.
/// Combines high-precision Air Mouse trackpad, circular D-pad with Play/Pause,
/// volume rockers, scroll rockers, and tactile mute control into a sleek landscape deck.
class RemoteSurface extends StatefulWidget {
  final ITransport transport;
  final VoidCallback onActivity;
  final RemoteDeckTab initialTab;

  const RemoteSurface({
    super.key,
    required this.transport,
    required this.onActivity,
    this.initialTab = RemoteDeckTab.remote,
  });

  @override
  State<RemoteSurface> createState() => _RemoteSurfaceState();
}

class _RemoteSurfaceState extends State<RemoteSurface> {
  String _activeFeedback = 'REMOTE ACTIVE';
  String? _lastPressedLabel;
  Timer? _feedbackTimer;
  final bool _isDragMode = false;
  bool _isMuted = false;
  final Map<int, TouchPoint> _activePointers = {};
  final ValueNotifier<int> _touchNotifier = ValueNotifier<int>(0);

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _touchNotifier.dispose();
    super.dispose();
  }

  void _showFeedback(String label) {
    widget.onActivity();
    HapticFeedback.lightImpact();
    setState(() {
      _activeFeedback = label;
      _lastPressedLabel = label;
    });

    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(milliseconds: 320), () {
      if (mounted) {
        setState(() {
          _lastPressedLabel = null;
        });
      }
    });
  }

  void _triggerMediaKey(MediaKey key, String label) {
    _showFeedback(label);
    widget.transport.sendPacket(PhonePadPacket(
      opcode: Opcode.media,
      dx: key.code,
    ));
  }

  void _triggerSpecialKey(SpecialKey key, String label) {
    _showFeedback(label);
    widget.transport.sendPacket(PhonePadPacket(
      opcode: Opcode.keyboard,
      dx: key.code,
      dy: KeyboardKeyType.specialKey,
    ));
  }

  void _triggerTapLeft() {
    _showFeedback('LEFT CLICK');
    widget.transport.sendPacket(const PhonePadPacket(
      opcode: Opcode.tapLeft,
      flags: 0x01,
    ));
  }

  void _triggerTapRight() {
    _showFeedback('RIGHT CLICK');
    widget.transport.sendPacket(const PhonePadPacket(
      opcode: Opcode.tapRight,
      flags: 0x02,
    ));
  }

  void _triggerScroll(int notches) {
    _showFeedback(notches > 0 ? 'SCROLL UP' : 'SCROLL DOWN');
    widget.transport.sendPacket(PhonePadPacket(
      opcode: Opcode.scroll,
      dx: 0,
      dy: notches,
      flags: PhonePadPacket.flagDiscreteNotch,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final theme = ThemeController.instance.theme;

        return Container(
          color: theme.isDark ? Colors.black : theme.backgroundPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: OrientationBuilder(
            builder: (context, orientation) {
              final isLandscape = orientation == Orientation.landscape;

              return Column(
                children: [
                  // Top Remote Bar: Live Feedback badge
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.surfaceCard.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: theme.borderSubtle),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.sensors_rounded,
                                size: 13,
                                color: _lastPressedLabel != null ? theme.accentPrimary : theme.textSecondary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _activeFeedback,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: _lastPressedLabel != null ? theme.accentPrimary : theme.textSecondary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content: Automatically adapts to device orientation:
                  // Landscape: Side-by-side (D-Pad Left flex 6, Air Mouse Right flex 5)
                  // Portrait: Vertically stacked layout
                  Expanded(
                    child: isLandscape
                        ? Row(
                            children: [
                              // Left Column: Media Remote & Circular D-Pad Controller
                              Expanded(
                                flex: 6,
                                child: _buildRemoteControlsSection(theme),
                              ),

                              const SizedBox(width: 10),

                              // Right Column: Air Mouse Trackpad Digitizer & Clickpads
                              Expanded(
                                flex: 5,
                                child: _buildAirMouseSection(theme),
                              ),
                            ],
                          )
                        : _buildVerticalModeContent(theme),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// Air Mouse Trackpad Area + Left & Right Click Buttons (Right side in horizontal layout)
  Widget _buildAirMouseSection(PhonePadThemeData theme) {
    return Column(
      children: [
        Expanded(
          child: _buildTouchpadBox(theme),
        ),
        const SizedBox(height: 8),
        _buildClickButtons(theme),
      ],
    );
  }

  /// Dedicated Air Mouse Touchpad Surface Container
  Widget _buildTouchpadBox(PhonePadThemeData theme) {
    final density = ThemeController.instance.dotDensity;

    return Container(
      decoration: BoxDecoration(
        color: theme.isDark ? Colors.black : theme.backgroundSecondary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            widget.onActivity();
            final point = TouchPoint(
              pointerId: event.pointer,
              current: event.localPosition,
              startTime: DateTime.now(),
            );
            _activePointers[event.pointer] = point;
            _touchNotifier.value++;
            setState(() {});
          },
          onPointerMove: (event) {
            widget.onActivity();
            final point = _activePointers[event.pointer];
            if (point != null) {
              final oldPos = point.current;
              point.update(event.localPosition);
              final delta = point.current - oldPos;
              widget.transport.sendPacket(PhonePadPacket(
                opcode: Opcode.move,
                dx: (delta.dx * 2.2).round(),
                dy: (delta.dy * 2.2).round(),
                flags: _isDragMode ? 0x05 : 0x01,
              ));
            }
            _touchNotifier.value++;
          },
          onPointerUp: (event) {
            widget.onActivity();
            final point = _activePointers.remove(event.pointer);
            if (point != null &&
                point.totalDisplacement < 10 &&
                point.contactDuration.inMilliseconds < 300) {
              _triggerTapLeft();
            }
            _touchNotifier.value++;
            setState(() {});
          },
          onPointerCancel: (event) {
            widget.onActivity();
            _activePointers.remove(event.pointer);
            _touchNotifier.value++;
            setState(() {});
          },
          child: CustomPaint(
            painter: SamsungDotMatrixPainter(
              activePointers: _activePointers,
              repaint: _touchNotifier,
              theme: theme,
              dotSpacing: density.spacing,
              baseDotRadius: density.baseRadius,
              maxDotRadius: density.maxRadius,
              containerBorderRadius: 20.0,
            ),
            child: _activePointers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.near_me_rounded,
                          color: theme.textSecondary.withValues(alpha: 0.3),
                          size: 26,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'AIR MOUSE PRECISION PAD\nSWIPE TO MOVE • TAP TO CLICK',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: theme.textSecondary.withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.expand(),
          ),
        ),
      ),
    );
  }

  /// Elevated, tactile Left & Right Click Buttons (Generous height & finger targets)
  Widget _buildClickButtons(PhonePadThemeData theme) {
    return SizedBox(
      height: 50,
      child: Row(
        children: [
          // Left Click (Primary)
          Expanded(
            child: SpringBounceTap(
              onTap: _triggerTapLeft,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      theme.surfaceCard.withValues(alpha: 0.95),
                      theme.backgroundSecondary.withValues(alpha: 0.85),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.accentPrimary.withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.accentPrimary.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0,vertical: 10.0),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.accentPrimary.withValues(alpha: 0.20),
                          ),
                          child: Icon(Icons.mouse_rounded, color: theme.accentPrimary, size: 18),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'LEFT CLICK',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: theme.textPrimary,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Right Click (Context)
          Expanded(
            child: SpringBounceTap(
              onTap: _triggerTapRight,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      theme.surfaceCard.withValues(alpha: 0.95),
                      theme.backgroundSecondary.withValues(alpha: 0.85),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.accentPrimary.withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.accentPrimary.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0,vertical: 10.0),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.accentSecondary.withValues(alpha: 0.20),
                          ),
                          child: Icon(Icons.touch_app_rounded, color: theme.accentSecondary, size: 18),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'RIGHT CLICK',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: theme.textPrimary,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
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

  /// Dedicated, beautiful Presentation Slide Controls (PREV / NEXT)
  Widget _buildSlideControls(PhonePadThemeData theme) {
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          Expanded(
            child: SpringBounceTap(
              onTap: () => _triggerMediaKey(MediaKey.prevSlide, 'PREV'),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      theme.surfaceCard.withValues(alpha: 0.92),
                      theme.backgroundSecondary.withValues(alpha: 0.80),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: theme.accentPrimary.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.accentPrimary.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0,vertical: 10.0),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.accentPrimary.withValues(alpha: 0.16),
                          ),
                          child: Icon(Icons.skip_previous_rounded, color: theme.accentPrimary, size: 18),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'PREV',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: theme.textPrimary,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SpringBounceTap(
              key: const Key('next_slide_btn'),
              onTap: () => _triggerMediaKey(MediaKey.nextSlide, 'NEXT'),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      theme.surfaceCard.withValues(alpha: 0.92),
                      theme.backgroundSecondary.withValues(alpha: 0.80),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: theme.accentPrimary.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.accentPrimary.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0,vertical: 10.0),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'NEXT',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: theme.textPrimary,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.accentPrimary.withValues(alpha: 0.16),
                          ),
                          child: Icon(Icons.skip_next_rounded, color: theme.accentPrimary, size: 18),
                        ),
                      ],
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

  /// Remote Section with Volume, Circular D-Pad (Play/Pause Center), Slide Stepper & Scroll
  Widget _buildRemoteControlsSection(PhonePadThemeData theme) {
    return Row(
      children: [
        // Column 1: Volume Rocker & Mute Button
        SizedBox(
          width: 58,
          child: Column(
            children: [
              Expanded(
                child: _buildVolumeRocker(theme),
              ),
              const SizedBox(height: 8),
              _buildMuteButton(theme),
            ],
          ),
        ),

        const SizedBox(width: 10),

        // Column 2: Center Glowing Circular D-Pad + Prev & Next Slide Stepper
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: _buildGlowingCircularDPad(theme, size: 175),
                ),
              ),
              const SizedBox(height: 8),
              _buildSlideControls(theme),
            ],
          ),
        ),

        const SizedBox(width: 10),

        // Column 3: Scroll Rocker & Escape Button
        SizedBox(
          width: 58,
          child: Column(
            children: [
              Expanded(
                child: _buildScrollRocker(theme),
              ),
              const SizedBox(height: 8),
              _buildEscButton(theme),
            ],
          ),
        ),
      ],
    );
  }

  /// Vertical Mode Content Layout: all sections stacked vertically and centered
  Widget _buildVerticalModeContent(PhonePadThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  // 1. D-Pad with flanking Volume & Scroll Rockers
                  SizedBox(
                    height: 235,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 58,
                          child: Column(
                            children: [
                              Expanded(child: _buildVolumeRocker(theme)),
                              const SizedBox(height: 6),
                              _buildMuteButton(theme),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Center(
                            child: _buildGlowingCircularDPad(theme, size: 210),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 58,
                          child: Column(
                            children: [
                              Expanded(child: _buildScrollRocker(theme)),
                              const SizedBox(height: 6),
                              _buildEscButton(theme),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. Slide Stepper Controls (PREV / NEXT)
                  _buildSlideControls(theme),
                  const SizedBox(height: 12),

                  // 3. Air Mouse Touchpad Surface
                  SizedBox(
                    height: 210,
                    child: _buildTouchpadBox(theme),
                  ),
                  const SizedBox(height: 12),

                  // 4. Polished Left & Right Click Buttons
                  _buildClickButtons(theme),
                  const Spacer(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVolumeRocker(PhonePadThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceCard.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Column(
        children: [
          Expanded(
            child: SpringBounceTap(
              key: const Key('vol_up_btn'),
              onHoldRepeat: () {
                if (_isMuted) setState(() => _isMuted = false);
                _triggerMediaKey(MediaKey.volumeUp, 'VOL +');
              },
              child: const Center(
                child: Icon(Icons.add_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
          Text(
            'VOL',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: theme.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
          Expanded(
            child: SpringBounceTap(
              key: const Key('vol_down_btn'),
              onHoldRepeat: () {
                if (_isMuted) setState(() => _isMuted = false);
                _triggerMediaKey(MediaKey.volumeDown, 'VOL -');
              },
              child: const Center(
                child: Icon(Icons.remove_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMuteButton(PhonePadThemeData theme) {
    final isMuted = _isMuted;
    final muteColor = isMuted ? PhonePadColors.errorRed : theme.accentPrimary;
    final muteBg = isMuted
        ? PhonePadColors.errorRed.withValues(alpha: 0.22)
        : theme.surfaceCard.withValues(alpha: 0.75);
    final muteBorder = isMuted
        ? PhonePadColors.errorRed.withValues(alpha: 0.85)
        : theme.borderSubtle;

    return SizedBox(
      height: 44,
      width: double.infinity,
      child: SpringBounceTap(
        key: const Key('mute_btn'),
        onTap: () {
          setState(() {
            _isMuted = !_isMuted;
          });
          _triggerMediaKey(MediaKey.mute, _isMuted ? 'MUTED' : 'UNMUTED');
        },
        child: Container(
          decoration: BoxDecoration(
            color: muteBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: muteBorder, width: isMuted ? 1.5 : 1.0),
            boxShadow: [
              if (isMuted)
                BoxShadow(
                  color: PhonePadColors.errorRed.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.volume_off_rounded, color: muteColor, size: 16),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isMuted) ...[
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: PhonePadColors.errorRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 3),
                  ],
                  Text(
                    isMuted ? 'MUTED' : 'MUTE',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: isMuted ? PhonePadColors.errorRed : theme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScrollRocker(PhonePadThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceCard.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Column(
        children: [
          Expanded(
            child: SpringBounceTap(
              key: const Key('scroll_up_btn'),
              repeatInitialDelay: const Duration(milliseconds: 450),
              repeatInterval: const Duration(milliseconds: 320),
              onHoldRepeat: () => _triggerScroll(1),
              child: const Center(
                child: Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
          Text(
            'SCROLL',
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              color: theme.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          Expanded(
            child: SpringBounceTap(
              key: const Key('scroll_down_btn'),
              repeatInitialDelay: const Duration(milliseconds: 450),
              repeatInterval: const Duration(milliseconds: 320),
              onHoldRepeat: () => _triggerScroll(-1),
              child: const Center(
                child: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEscButton(PhonePadThemeData theme) {
    return SizedBox(
      height: 44,
      width: double.infinity,
      child: SpringBounceTap(
        onTap: () => _triggerSpecialKey(SpecialKey.escape, 'ESC'),
        child: Container(
          decoration: BoxDecoration(
            color: theme.surfaceCard.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.borderSubtle),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.close_fullscreen_rounded, color: theme.textSecondary, size: 16),
              const SizedBox(height: 2),
              Text(
                'ESC',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: theme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Circular D-Pad with directional ring and PLAY / PAUSE in the center
  Widget _buildGlowingCircularDPad(PhonePadThemeData theme, {required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.surfaceCard.withValues(alpha: 0.85),
        border: Border.all(
          color: theme.accentPrimary.withValues(alpha: 0.5),
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.accentPrimary.withValues(alpha: 0.18),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Up
          Positioned(
            top: 6,
            child: SpringBounceTap(
              key: const Key('dpad_up_btn'),
              onHoldRepeat: () => _triggerSpecialKey(SpecialKey.arrowUp, 'UP'),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white, size: 26),
              ),
            ),
          ),
          // Down
          Positioned(
            bottom: 6,
            child: SpringBounceTap(
              key: const Key('dpad_down_btn'),
              onHoldRepeat: () => _triggerSpecialKey(SpecialKey.arrowDown, 'DOWN'),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 26),
              ),
            ),
          ),
          // Left
          Positioned(
            left: 6,
            child: SpringBounceTap(
              key: const Key('dpad_left_btn'),
              onHoldRepeat: () => _triggerSpecialKey(SpecialKey.arrowLeft, 'LEFT'),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.keyboard_arrow_left_rounded, color: Colors.white, size: 26),
              ),
            ),
          ),
          // Right
          Positioned(
            right: 6,
            child: SpringBounceTap(
              key: const Key('dpad_right_btn'),
              onHoldRepeat: () => _triggerSpecialKey(SpecialKey.arrowRight, 'RIGHT'),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.keyboard_arrow_right_rounded, color: Colors.white, size: 26),
              ),
            ),
          ),

          // Center Button: PLAY / PAUSE (replaces OK!)
          SpringBounceTap(
            key: const Key('play_pause_btn'),
            onTap: () => _triggerMediaKey(MediaKey.playPause, 'PLAY / PAUSE'),
            child: Container(
              width: size * 0.40,
              height: size * 0.40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    theme.accentPrimary,
                    Color.lerp(theme.accentPrimary, Colors.blue.shade900, 0.4)!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.accentPrimary.withValues(alpha: 0.45),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                  const SizedBox(height: 1),
                  const Text(
                    'PLAY',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 9,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
