import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/network/transport.dart';
import '../../../core/protocol/keys.dart';
import '../../../core/protocol/opcode.dart';
import '../../../core/protocol/packet.dart';
import '../../../core/theme/liquid_glass_container.dart';
import '../../../core/theme/spring_bounce_tap.dart';
import '../../../core/theme/theme_controller.dart';

/// Ultra-modern tactile studio remote with circular media dial and slide deck.
class RemoteSurface extends StatefulWidget {
  final ITransport transport;
  final VoidCallback onActivity;

  const RemoteSurface({
    super.key,
    required this.transport,
    required this.onActivity,
  });

  @override
  State<RemoteSurface> createState() => _RemoteSurfaceState();
}

class _RemoteSurfaceState extends State<RemoteSurface> {
  String _activeFeedback = 'READY';
  MediaKey? _lastPressedKey;
  Timer? _feedbackTimer;

  void _triggerKey(MediaKey key, String label) {
    widget.onActivity();
    HapticFeedback.mediumImpact();
    setState(() {
      _activeFeedback = label;
      _lastPressedKey = key;
    });

    widget.transport.sendPacket(PhonePadPacket(
      opcode: Opcode.media,
      dx: key.code,
    ));

    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(milliseconds: 280), () {
      if (mounted && _lastPressedKey == key) {
        setState(() {
          _lastPressedKey = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final theme = ThemeController.instance.theme;

        return Container(
          color: theme.backgroundPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: OrientationBuilder(
            builder: (context, orientation) {
              final isLandscape = orientation == Orientation.landscape;

              return Column(
                children: [
                  _buildStatusHeader(theme),
                  const SizedBox(height: 8),
                  Expanded(
                    child: isLandscape
                        ? _buildLandscapeLayout(theme)
                        : _buildPortraitLayout(theme),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// Telemetry status pill at the top of the remote deck
  Widget _buildStatusHeader(PhonePadThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: theme.surfaceCard.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: theme.accentPrimary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.accentPrimary.withValues(alpha: 0.7),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'STUDIO CONTROLLER',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: theme.textSecondary,
                ),
              ),
            ],
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: _lastPressedKey != null
                  ? theme.accentPrimary.withValues(alpha: 0.25)
                  : theme.surfaceCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _lastPressedKey != null
                    ? theme.accentPrimary.withValues(alpha: 0.6)
                    : Colors.transparent,
              ),
            ),
            child: Text(
              _activeFeedback,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: _lastPressedKey != null
                    ? theme.accentPrimary
                    : theme.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Clean portrait layout: Circular D-Pad Dial + Slide triggers + Quick action dock
  Widget _buildPortraitLayout(PhonePadThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // Primary Presentation Hero Triggers (Prev & Next Slide)
                  Row(
                    children: [
                      Expanded(
                        child: _buildTactileButton(
                          key: const Key('prev_slide_btn'),
                          title: 'PREV',
                          subtitle: 'PAGE UP',
                          icon: Icons.skip_previous_rounded,
                          theme: theme,
                          isPrimary: false,
                          onTap: () => _triggerKey(MediaKey.prevSlide, 'PREV SLIDE'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTactileButton(
                          key: const Key('next_slide_btn'),
                          title: 'NEXT',
                          subtitle: 'PAGE DOWN',
                          icon: Icons.skip_next_rounded,
                          theme: theme,
                          isPrimary: true,
                          onTap: () => _triggerKey(MediaKey.nextSlide, 'NEXT SLIDE'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Centerpiece: Circular Media Wheel Dial
                  Expanded(
                    child: Center(
                      child: _buildCircularMediaWheel(theme, size: 240),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Bottom Quick Utility Deck (Mute, Nav Back, Nav Forward)
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickActionPill(
                          title: 'MUTE',
                          icon: Icons.volume_off_rounded,
                          theme: theme,
                          isDestructive: true,
                          onTap: () => _triggerKey(MediaKey.mute, 'AUDIO MUTE'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildQuickActionPill(
                          title: 'BACK',
                          icon: Icons.arrow_back_rounded,
                          theme: theme,
                          onTap: () => _triggerKey(MediaKey.navBack, 'BROWSER BACK'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildQuickActionPill(
                          title: 'FORWARD',
                          icon: Icons.arrow_forward_rounded,
                          theme: theme,
                          onTap: () => _triggerKey(MediaKey.navForward, 'BROWSER FWD'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Compact side-by-side landscape layout
  Widget _buildLandscapeLayout(PhonePadThemeData theme) {
    return Row(
      children: [
        // Left Column: Circular Controller Wheel
        Expanded(
          flex: 5,
          child: Center(
            child: _buildCircularMediaWheel(theme, size: 190),
          ),
        ),
        const SizedBox(width: 16),

        // Right Column: Slide Presentation Cards & Utility Buttons
        Expanded(
          flex: 6,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTactileButton(
                        key: const Key('prev_slide_btn'),
                        title: 'PREV',
                        subtitle: 'PAGE UP',
                        icon: Icons.skip_previous_rounded,
                        theme: theme,
                        isPrimary: false,
                        onTap: () => _triggerKey(MediaKey.prevSlide, 'PREV SLIDE'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTactileButton(
                        key: const Key('next_slide_btn'),
                        title: 'NEXT',
                        subtitle: 'PAGE DOWN',
                        icon: Icons.skip_next_rounded,
                        theme: theme,
                        isPrimary: true,
                        onTap: () => _triggerKey(MediaKey.nextSlide, 'NEXT SLIDE'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildQuickActionPill(
                      title: 'MUTE',
                      icon: Icons.volume_off_rounded,
                      theme: theme,
                      isDestructive: true,
                      onTap: () => _triggerKey(MediaKey.mute, 'AUDIO MUTE'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQuickActionPill(
                      title: 'BACK',
                      icon: Icons.arrow_back_rounded,
                      theme: theme,
                      onTap: () => _triggerKey(MediaKey.navBack, 'BROWSER BACK'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQuickActionPill(
                      title: 'FORWARD',
                      icon: Icons.arrow_forward_rounded,
                      theme: theme,
                      onTap: () => _triggerKey(MediaKey.navForward, 'BROWSER FWD'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Circular tactile D-Pad Jog Wheel for Media & Slides
  Widget _buildCircularMediaWheel(PhonePadThemeData theme, {required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.surfaceCard.withValues(alpha: 0.8),
        border: Border.all(color: theme.borderSubtle, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Top: Volume Up
          Positioned(
            top: 10,
            child: _buildWheelDirectionButton(
              key: const Key('vol_up_btn'),
              icon: Icons.volume_up_rounded,
              label: 'VOL +',
              theme: theme,
              onTap: () => _triggerKey(MediaKey.volumeUp, 'VOLUME +'),
            ),
          ),

          // Bottom: Volume Down
          Positioned(
            bottom: 10,
            child: _buildWheelDirectionButton(
              key: const Key('vol_down_btn'),
              icon: Icons.volume_down_rounded,
              label: 'VOL -',
              theme: theme,
              onTap: () => _triggerKey(MediaKey.volumeDown, 'VOLUME -'),
            ),
          ),

          // Left: Prev Track / Slide
          Positioned(
            left: 10,
            child: _buildWheelDirectionButton(
              icon: Icons.fast_rewind_rounded,
              label: 'PREV',
              theme: theme,
              onTap: () => _triggerKey(MediaKey.prevSlide, 'PREV TRACK'),
            ),
          ),

          // Right: Next Track / Slide
          Positioned(
            right: 10,
            child: _buildWheelDirectionButton(
              icon: Icons.fast_forward_rounded,
              label: 'NEXT',
              theme: theme,
              onTap: () => _triggerKey(MediaKey.nextSlide, 'NEXT TRACK'),
            ),
          ),

          // Center: Play / Pause Hero Button
          GestureDetector(
            key: const Key('play_pause_btn'),
            onTap: () => _triggerKey(MediaKey.playPause, 'PLAY / PAUSE'),
            child: Container(
              width: size * 0.44,
              height: size * 0.44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    theme.accentPrimary.withValues(alpha: 0.95),
                    theme.accentPrimary.withValues(alpha: 0.75),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.accentPrimary.withValues(alpha: 0.4),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.play_arrow_rounded,
                    size: 30,
                    color: Colors.black,
                  ),
                  Text(
                    'Play / Pause',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
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

  Widget _buildWheelDirectionButton({
    Key? key,
    required IconData icon,
    required String label,
    required PhonePadThemeData theme,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.backgroundPrimary.withValues(alpha: 0.45),
        ),
        child: Icon(
          icon,
          size: 26,
          color: theme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildTactileButton({
    Key? key,
    required String title,
    required String subtitle,
    required IconData icon,
    required PhonePadThemeData theme,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    final accent = isPrimary ? theme.accentPrimary : theme.accentSecondary;

    return SpringBounceTap(
      key: key,
      onTap: onTap,
      pressedScale: 0.94,
      bounceOvershoot: 1.05,
      child: LiquidGlassContainer(
        blur: 16,
        borderRadius: BorderRadius.circular(20),
        backgroundColor: theme.surfaceCard.withValues(alpha: 0.85),
        borderColor: accent.withValues(alpha: isPrimary ? 0.45 : 0.25),
        borderWidth: 1.3,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shadows: [
          if (isPrimary)
            BoxShadow(
              color: accent.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: accent.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: accent, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: theme.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: theme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionPill({
    required String title,
    required IconData icon,
    required PhonePadThemeData theme,
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    final color = isDestructive ? const Color(0xFFEF4444) : theme.textPrimary;

    return SpringBounceTap(
      onTap: onTap,
      pressedScale: 0.92,
      bounceOvershoot: 1.06,
      child: LiquidGlassContainer(
        blur: 12,
        borderRadius: BorderRadius.circular(14),
        backgroundColor: theme.surfaceCard.withValues(alpha: 0.8),
        borderColor: isDestructive
            ? const Color(0xFFEF4444).withValues(alpha: 0.4)
            : theme.borderSubtle,
        borderWidth: 1.1,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
