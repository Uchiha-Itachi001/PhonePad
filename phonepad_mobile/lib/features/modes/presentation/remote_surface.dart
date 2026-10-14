import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/network/transport.dart';
import '../../../core/protocol/keys.dart';
import '../../../core/protocol/opcode.dart';
import '../../../core/protocol/packet.dart';
import '../../../core/theme/spring_bounce_tap.dart';
import '../../../core/theme/theme_controller.dart';

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

  @override
  void dispose() {
    _feedbackTimer?.cancel();
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

  void _triggerScroll(int delta) {
    _showFeedback(delta > 0 ? 'SCROLL UP' : 'SCROLL DOWN');
    widget.transport.sendPacket(PhonePadPacket(
      opcode: Opcode.scroll,
      dy: delta,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final theme = ThemeController.instance.theme;

        return Container(
          color: theme.backgroundPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              // Left Column: Air Mouse Trackpad Digitizer & Clickpads
              Expanded(
                flex: 5,
                child: _buildAirMouseSection(theme),
              ),

              const SizedBox(width: 12),

              // Right Column: Media Remote & Glowing D-Pad Controller
              Expanded(
                flex: 6,
                child: _buildRemoteControlsSection(theme),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Air Mouse Trackpad Area + Left & Right Click Buttons
  Widget _buildAirMouseSection(PhonePadThemeData theme) {
    return Column(
      children: [
        // Touch Surface with Crosshair and Gyro/Mouse Indicator
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (details) {
              widget.onActivity();
              widget.transport.sendPacket(PhonePadPacket(
                opcode: Opcode.move,
                dx: (details.delta.dx * 2.2).round(),
                dy: (details.delta.dy * 2.2).round(),
                flags: _isDragMode ? 0x05 : 0x01,
              ));
            },
            onTap: _triggerTapLeft,
            child: Container(
              decoration: BoxDecoration(
                color: theme.backgroundSecondary.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.borderSubtle,
                  width: 1.2,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Crosshairs
                  Container(width: 1, color: theme.borderSubtle.withValues(alpha: 0.5)),
                  Container(height: 1, color: theme.borderSubtle.withValues(alpha: 0.5)),

                  // Direction Indicators
                  Positioned(
                    top: 10,
                    child: Icon(Icons.keyboard_arrow_up_rounded,
                        color: theme.textSecondary.withValues(alpha: 0.4), size: 22),
                  ),
                  Positioned(
                    bottom: 10,
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        color: theme.textSecondary.withValues(alpha: 0.4), size: 22),
                  ),
                  Positioned(
                    left: 10,
                    child: Icon(Icons.keyboard_arrow_left_rounded,
                        color: theme.textSecondary.withValues(alpha: 0.4), size: 22),
                  ),
                  Positioned(
                    right: 10,
                    child: Icon(Icons.keyboard_arrow_right_rounded,
                        color: theme.textSecondary.withValues(alpha: 0.4), size: 22),
                  ),

                  // Center Cursor Emblem
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.accentPrimary.withValues(alpha: 0.20),
                      border: Border.all(color: theme.accentPrimary.withValues(alpha: 0.7), width: 1.5),
                    ),
                    child: const Center(
                      child: Icon(Icons.navigation_rounded, color: Colors.white, size: 20),
                    ),
                  ),

                  // Feedback Overlay at Top
                  Positioned(
                    top: 8,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.surfaceCard.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.borderSubtle),
                      ),
                      child: Text(
                        _activeFeedback,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: _lastPressedLabel != null ? theme.accentPrimary : theme.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Left Click & Right Click tactile buttons
        SizedBox(
          height: 44,
          child: Row(
            children: [
              Expanded(
                child: SpringBounceTap(
                  onTap: _triggerTapLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.surfaceCard.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: theme.accentPrimary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.mouse_rounded, color: theme.accentPrimary, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'LEFT CLICK',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: theme.textPrimary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SpringBounceTap(
                  onTap: _triggerTapRight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.surfaceCard.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: theme.borderSubtle),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.menu_open_rounded, color: theme.textSecondary, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'RIGHT CLICK',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: theme.textPrimary,
                            letterSpacing: 0.5,
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
      ],
    );
  }

  /// Remote Section with Volume, Circular D-Pad (Play/Pause Center), Scroll, Mute, Slides
  Widget _buildRemoteControlsSection(PhonePadThemeData theme) {
    return Row(
      children: [
        // Column 1: Volume Rocker & Mute Button
        SizedBox(
          width: 58,
          child: Column(
            children: [
              // Volume Rocker
              Expanded(
                child: Container(
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
                          onTap: () => _triggerMediaKey(MediaKey.volumeUp, 'VOL +'),
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
                          onTap: () => _triggerMediaKey(MediaKey.volumeDown, 'VOL -'),
                          child: const Center(
                            child: Icon(Icons.remove_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Dedicated Mute Button
              SizedBox(
                height: 44,
                width: double.infinity,
                child: SpringBounceTap(
                  onTap: () => _triggerMediaKey(MediaKey.mute, 'MUTE'),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.surfaceCard.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: theme.borderSubtle),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.volume_off_rounded, color: theme.accentPrimary, size: 16),
                        const SizedBox(height: 2),
                        Text(
                          'MUTE',
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
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        // Column 2: Center Glowing Circular D-Pad with Play/Pause in Center
        Expanded(
          child: Center(
            child: _buildGlowingCircularDPad(theme, size: 185),
          ),
        ),

        const SizedBox(width: 12),

        // Column 3: Scroll Rocker & Presentation Slides
        SizedBox(
          width: 58,
          child: Column(
            children: [
              // Scroll Up / Down Rocker (replaces channel)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.surfaceCard.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.borderSubtle),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: SpringBounceTap(
                          onTap: () => _triggerScroll(120),
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
                          onTap: () => _triggerScroll(-120),
                          child: const Center(
                            child: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Slide Deck Controls
              SizedBox(
                height: 44,
                width: double.infinity,
                child: Row(
                  children: [
                    Expanded(
                      child: SpringBounceTap(
                        onTap: () => _triggerMediaKey(MediaKey.prevSlide, 'PREV'),
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.surfaceCard.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.borderSubtle),
                          ),
                          child: Center(
                            child: Text(
                              'PREV',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: theme.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: SpringBounceTap(
                        key: const Key('next_slide_btn'),
                        onTap: () => _triggerMediaKey(MediaKey.nextSlide, 'NEXT'),
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.surfaceCard.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.borderSubtle),
                          ),
                          child: Center(
                            child: Text(
                              'NEXT',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: theme.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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
              onTap: () => _triggerSpecialKey(SpecialKey.arrowUp, 'UP'),
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
              onTap: () => _triggerSpecialKey(SpecialKey.arrowDown, 'DOWN'),
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
              onTap: () => _triggerSpecialKey(SpecialKey.arrowLeft, 'LEFT'),
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
              onTap: () => _triggerSpecialKey(SpecialKey.arrowRight, 'RIGHT'),
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
