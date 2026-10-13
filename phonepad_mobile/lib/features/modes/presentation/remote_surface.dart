import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/network/transport.dart';
import '../../../core/protocol/keys.dart';
import '../../../core/protocol/opcode.dart';
import '../../../core/protocol/packet.dart';
import '../../../core/theme/theme_controller.dart';

/// Presentation & Media Remote surface with responsive orientation and glassmorphic styling.
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
  String _lastActionLabel = 'REMOTE READY';

  void _onKeyPress(MediaKey key, String label) {
    widget.onActivity();
    HapticFeedback.lightImpact();
    setState(() {
      _lastActionLabel = label;
    });
    widget.transport.sendPacket(PhonePadPacket(
      opcode: Opcode.media,
      dx: key.code,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: OrientationBuilder(
            builder: (context, orientation) {
              final isLandscape = orientation == Orientation.landscape;

              return Column(
                children: [
                  // Top Deck Status Bar
                  _buildHeader(theme),
                  const SizedBox(height: 10),

                  // Main Content
                  Expanded(
                    child: isLandscape
                        ? _buildLandscapeContent(theme)
                        : _buildPortraitContent(theme),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHeader(PhonePadThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: theme.surfaceCard.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: theme.accentSecondary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.accentSecondary.withValues(alpha: 0.8),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'STUDIO REMOTE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: theme.textSecondary,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.accentSecondary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _lastActionLabel,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: theme.accentSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortraitContent(PhonePadThemeData theme) {
    return Column(
      children: [
        // Section: Presentation Slide Controller
        _buildSectionHeader('PRESENTATION SLIDES', Icons.slideshow_rounded, theme),
        const SizedBox(height: 8),
        Expanded(
          flex: 3,
          child: Row(
            children: [
              Expanded(
                child: _buildSlideButton(
                  keyId: 'prev_slide_btn',
                  label: 'PREV',
                  sublabel: 'PAGE UP',
                  icon: Icons.arrow_back_rounded,
                  theme: theme,
                  isPrimary: false,
                  onTap: () => _onKeyPress(MediaKey.prevSlide, 'PREV SLIDE'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSlideButton(
                  keyId: 'next_slide_btn',
                  label: 'NEXT',
                  sublabel: 'PAGE DOWN',
                  icon: Icons.arrow_forward_rounded,
                  theme: theme,
                  isPrimary: true,
                  onTap: () => _onKeyPress(MediaKey.nextSlide, 'NEXT SLIDE'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Section: Media & Audio Controls
        _buildSectionHeader('MEDIA & VOLUME', Icons.music_note_rounded, theme),
        const SizedBox(height: 8),
        Expanded(
          flex: 2,
          child: Row(
            children: [
              // Hero Play/Pause Card
              Expanded(
                flex: 3,
                child: _buildHeroPlayButton(theme),
              ),
              const SizedBox(width: 10),

              // Volume Column (Vol Up & Vol Down)
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Expanded(
                      child: _buildActionIconButton(
                        keyId: 'vol_up_btn',
                        icon: Icons.volume_up_rounded,
                        tooltip: 'VOL +',
                        theme: theme,
                        onTap: () => _onKeyPress(MediaKey.volumeUp, 'VOL +'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: _buildActionIconButton(
                        keyId: 'vol_down_btn',
                        icon: Icons.volume_down_rounded,
                        tooltip: 'VOL -',
                        theme: theme,
                        onTap: () => _onKeyPress(MediaKey.volumeDown, 'VOL -'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Mute Button
              Expanded(
                flex: 2,
                child: _buildActionIconButton(
                  keyId: 'mute_btn',
                  icon: Icons.volume_off_rounded,
                  tooltip: 'MUTE',
                  theme: theme,
                  isDestructive: true,
                  onTap: () => _onKeyPress(MediaKey.mute, 'MUTE'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeContent(PhonePadThemeData theme) {
    return Row(
      children: [
        // Left Column: Presentation Slides
        Expanded(
          flex: 5,
          child: Column(
            children: [
              _buildSectionHeader('PRESENTATION SLIDES', Icons.slideshow_rounded, theme),
              const SizedBox(height: 6),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSlideButton(
                        keyId: 'prev_slide_btn',
                        label: 'PREV',
                        sublabel: 'PAGE UP',
                        icon: Icons.arrow_back_rounded,
                        theme: theme,
                        isPrimary: false,
                        onTap: () => _onKeyPress(MediaKey.prevSlide, 'PREV SLIDE'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildSlideButton(
                        keyId: 'next_slide_btn',
                        label: 'NEXT',
                        sublabel: 'PAGE DOWN',
                        icon: Icons.arrow_forward_rounded,
                        theme: theme,
                        isPrimary: true,
                        onTap: () => _onKeyPress(MediaKey.nextSlide, 'NEXT SLIDE'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),

        // Right Column: Media Playback & Volume
        Expanded(
          flex: 5,
          child: Column(
            children: [
              _buildSectionHeader('MEDIA & VOLUME', Icons.music_note_rounded, theme),
              const SizedBox(height: 6),
              Expanded(
                child: Row(
                  children: [
                    // Play/Pause
                    Expanded(
                      flex: 3,
                      child: _buildHeroPlayButton(theme),
                    ),
                    const SizedBox(width: 8),

                    // Volume Controls
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          Expanded(
                            child: _buildActionIconButton(
                              keyId: 'vol_up_btn',
                              icon: Icons.volume_up_rounded,
                              tooltip: 'VOL +',
                              theme: theme,
                              onTap: () => _onKeyPress(MediaKey.volumeUp, 'VOL +'),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: _buildActionIconButton(
                              keyId: 'vol_down_btn',
                              icon: Icons.volume_down_rounded,
                              tooltip: 'VOL -',
                              theme: theme,
                              onTap: () => _onKeyPress(MediaKey.volumeDown, 'VOL -'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Mute
                    Expanded(
                      flex: 2,
                      child: _buildActionIconButton(
                        keyId: 'mute_btn',
                        icon: Icons.volume_off_rounded,
                        tooltip: 'MUTE',
                        theme: theme,
                        isDestructive: true,
                        onTap: () => _onKeyPress(MediaKey.mute, 'MUTE'),
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

  Widget _buildSectionHeader(String title, IconData icon, PhonePadThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 12, color: theme.accentSecondary),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: theme.textSecondary.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildSlideButton({
    required String keyId,
    required String label,
    required String sublabel,
    required IconData icon,
    required PhonePadThemeData theme,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    final accent = isPrimary ? theme.accentPrimary : theme.accentSecondary;

    return Material(
      key: Key(keyId),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        splashColor: accent.withValues(alpha: 0.3),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: theme.surfaceCard.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isPrimary
                  ? accent.withValues(alpha: 0.5)
                  : theme.borderSubtle,
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: isPrimary
                    ? accent.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 26, color: accent),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: theme.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                sublabel,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: theme.textSecondary.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroPlayButton(PhonePadThemeData theme) {
    return Material(
      key: const Key('play_pause_btn'),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        splashColor: theme.accentPrimary.withValues(alpha: 0.3),
        onTap: () => _onKeyPress(MediaKey.playPause, 'PLAY / PAUSE'),
        child: Container(
          decoration: BoxDecoration(
            color: theme.surfaceCard.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.accentPrimary.withValues(alpha: 0.4),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.accentPrimary.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.accentPrimary,
                      theme.accentPrimary.withValues(alpha: 0.8),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.accentPrimary.withValues(alpha: 0.4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 24,
                  color: theme.isDark ? Colors.black : Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Play / Pause',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: theme.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionIconButton({
    required String keyId,
    required IconData icon,
    required String tooltip,
    required PhonePadThemeData theme,
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    final accent = isDestructive
        ? const Color(0xFFEF4444)
        : theme.accentSecondary;

    return Material(
      key: Key(keyId),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        splashColor: accent.withValues(alpha: 0.3),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: theme.surfaceCard.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDestructive
                  ? accent.withValues(alpha: 0.4)
                  : theme.borderSubtle,
              width: 1.0,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: accent),
              const SizedBox(height: 2),
              Text(
                tooltip,
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
