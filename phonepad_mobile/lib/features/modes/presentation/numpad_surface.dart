import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/network/transport.dart';
import '../../../core/protocol/keys.dart';
import '../../../core/protocol/opcode.dart';
import '../../../core/protocol/packet.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/liquid_glass_container.dart';
import '../../../core/theme/spring_bounce_tap.dart';
import '../../../core/theme/theme_controller.dart';
import '../models/surface_mode.dart';
import 'keyboard_deck.dart';

/// Virtual 10-key numeric keypad and QWERTY keyboard with glassmorphic tactile keys.
class NumpadSurface extends StatefulWidget {
  final ITransport transport;
  final VoidCallback onActivity;
  final SurfaceMode currentMode;
  final ValueChanged<SurfaceMode>? onModeChanged;
  final VoidCallback? onSettingsTap;
  final ConnectionStatus? connectionStatus;

  const NumpadSurface({
    super.key,
    required this.transport,
    required this.onActivity,
    this.currentMode = SurfaceMode.keyboard,
    this.onModeChanged,
    this.onSettingsTap,
    this.connectionStatus,
  });

  @override
  State<NumpadSurface> createState() => _NumpadSurfaceState();
}

class _NumpadSurfaceState extends State<NumpadSurface> {
  String _lastPressedKey = 'READY';
  bool _isKeyboardMode = true; // Keyboard active by default

  void _onKeyPress(NumpadKey key) {
    widget.onActivity();
    if (key == NumpadKey.enter) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    setState(() {
      _lastPressedKey = key.label;
    });
    widget.transport.sendPacket(PhonePadPacket(
      opcode: Opcode.numpad,
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
          color: theme.isDark ? Colors.black : theme.backgroundPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: _buildLandscapeLayout(theme),
        );
      },
    );
  }


  Widget _buildLandscapeLayout(PhonePadThemeData theme) {
    if (_isKeyboardMode) {
      return Column(
        children: [
          _buildTelemetryHeader(theme),
          const SizedBox(height: 6),
          Expanded(
            child: KeyboardDeck(
              transport: widget.transport,
              onActivity: widget.onActivity,
              onKeyNameChanged: (name) => setState(() => _lastPressedKey = name),
            ),
          ),
        ],
      );
    }

    const leftKeys = [
      [NumpadKey.num7, NumpadKey.num8, NumpadKey.num9],
      [NumpadKey.num4, NumpadKey.num5, NumpadKey.num6],
      [NumpadKey.num1, NumpadKey.num2, NumpadKey.num3],
      [NumpadKey.num0, NumpadKey.decimal, NumpadKey.backspace],
    ];

    const operatorKeys = [
      NumpadKey.divide,
      NumpadKey.multiply,
      NumpadKey.subtract,
      NumpadKey.add,
    ];

    return Column(
      children: [
        _buildTelemetryHeader(theme),
        const SizedBox(height: 6),
        Expanded(
          child: Row(
            children: [
              // Digits Block (3 columns)
              Expanded(
                flex: 6,
                child: Column(
                  children: leftKeys.map((row) {
                    return Expanded(
                      child: Row(
                        children: row.map((key) {
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(3.0),
                              child: _buildNumpadButton(key, theme),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 6),

              // Operators Column
              Expanded(
                flex: 2,
                child: Column(
                  children: operatorKeys.map((key) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(3.0),
                        child: _buildNumpadButton(key, theme),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 6),

              // Tall Enter Key
              Expanded(
                flex: 3,
                child: _buildEnterButton(theme),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTelemetryHeader(PhonePadThemeData theme) {
    Color statusColor;
    IconData statusIcon;

    switch (widget.connectionStatus ?? ConnectionStatus.connected) {
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

    return LiquidGlassContainer(
      height: 48,
      blur: 24.0,
      borderRadius: BorderRadius.circular(16),
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
          color: theme.accentPrimary.withValues(alpha: 0.16),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.5),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // Segmented Deck Switcher (Icons only, no text)
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: theme.isDark
                  ? const Color(0xFF0C101A).withValues(alpha: 0.9)
                  : theme.surfaceCard.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.isDark
                    ? const Color(0xFF22293C)
                    : theme.borderSubtle,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModeTab(
                  key: const Key('deck_switch_numpad_btn'),
                  tooltip: '123 Numpad',
                  icon: Icons.dialpad_rounded,
                  isSelected: !_isKeyboardMode,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _isKeyboardMode = false;
                      _lastPressedKey = 'NUMPAD';
                    });
                  },
                  theme: theme,
                ),
                const SizedBox(width: 4),
                _buildModeTab(
                  key: const Key('deck_switch_keyboard_btn'),
                  tooltip: 'QWERTY Keyboard',
                  icon: Icons.keyboard_rounded,
                  isSelected: _isKeyboardMode,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _isKeyboardMode = true;
                      _lastPressedKey = 'KEYBOARD';
                    });
                  },
                  theme: theme,
                ),
              ],
            ),
          ),

          // Telemetry feedback badge (fixed width child, not Flexible, so Spacer pushes nav to corner)
          if (_lastPressedKey.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: theme.accentPrimary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: theme.accentPrimary.withValues(alpha: 0.45),
                  width: 1.0,
                ),
              ),
              child: Text(
                _lastPressedKey,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: theme.accentPrimary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],

          // Spacer pushes navigation tabs fully to the corner with zero trailing gap
          const Spacer(),

          // Navigation section in same deck (Icons only, safe distance so no mistouch occurs)
          if (widget.onModeChanged != null || widget.onSettingsTap != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.isDark
                    ? const Color(0xFF0C101A).withValues(alpha: 0.9)
                    : theme.surfaceCard.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.isDark
                      ? const Color(0xFF22293C)
                      : theme.borderSubtle,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildNavIconButton(
                    icon: Icons.touch_app_rounded,
                    tooltip: 'Trackpad',
                    isSelected: widget.currentMode == SurfaceMode.trackpad,
                    onTap: () => widget.onModeChanged?.call(SurfaceMode.trackpad),
                    theme: theme,
                  ),
                  const SizedBox(width: 4),
                  _buildNavIconButton(
                    icon: Icons.keyboard_rounded,
                    tooltip: 'Keyboard',
                    isSelected: widget.currentMode == SurfaceMode.keyboard,
                    onTap: () => widget.onModeChanged?.call(SurfaceMode.keyboard),
                    theme: theme,
                  ),
                  const SizedBox(width: 4),
                  _buildNavIconButton(
                    icon: Icons.settings_remote_rounded,
                    tooltip: 'Remote',
                    isSelected: widget.currentMode == SurfaceMode.remote,
                    onTap: () => widget.onModeChanged?.call(SurfaceMode.remote),
                    theme: theme,
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 1,
                    height: 18,
                    color: theme.isDark
                        ? const Color(0xFF22293C)
                        : theme.borderSubtle,
                  ),
                  const SizedBox(width: 6),
                  SpringBounceTap(
                    onTap: widget.onSettingsTap ?? () {},
                    child: Tooltip(
                      message: widget.connectionStatus == ConnectionStatus.connected ? 'Connected' : 'Connection Hub',
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: statusColor.withValues(alpha: 0.15),
                          border: Border.all(color: statusColor.withValues(alpha: 0.5), width: 1.0),
                        ),
                        child: Icon(statusIcon, color: statusColor, size: 15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  SpringBounceTap(
                    onTap: widget.onSettingsTap ?? () {},
                    child: Tooltip(
                      message: 'Settings',
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: theme.isDark
                              ? const Color(0xFF141824)
                              : theme.surfaceCard,
                          border: Border.all(
                            color: theme.isDark
                                ? const Color(0xFF262E44)
                                : theme.borderSubtle,
                          ),
                        ),
                        child: Icon(Icons.tune_rounded, size: 14, color: theme.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNavIconButton({
    required IconData icon,
    required String tooltip,
    required bool isSelected,
    required VoidCallback onTap,
    required PhonePadThemeData theme,
  }) {
    return SpringBounceTap(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isSelected
                ? theme.accentPrimary.withValues(alpha: 0.25)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? theme.accentPrimary.withValues(alpha: 0.65) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isSelected ? theme.accentPrimary : theme.textSecondary.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }

  Widget _buildModeTab({
    Key? key,
    required String tooltip,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required PhonePadThemeData theme,
  }) {
    return Material(
      key: key,
      color: Colors.transparent,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 32,
            height: 28,
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        theme.accentPrimary.withValues(alpha: 0.32),
                        theme.accentPrimary.withValues(alpha: 0.16),
                      ],
                    )
                  : null,
              color: isSelected ? null : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? theme.accentPrimary.withValues(alpha: 0.70)
                    : Colors.transparent,
                width: 1.0,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: theme.accentPrimary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 1),
                  ),
              ],
            ),
            child: Center(
              child: Icon(
                icon,
                size: 16,
                color: isSelected ? theme.accentPrimary : theme.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumpadButton(NumpadKey key, PhonePadThemeData theme) {
    final isOperator = key == NumpadKey.divide ||
        key == NumpadKey.multiply ||
        key == NumpadKey.subtract ||
        key == NumpadKey.add ||
        key == NumpadKey.backspace;

    final bgColor = isOperator
        ? theme.accentSecondary.withValues(alpha: 0.18)
        : (theme.isDark
            ? const Color(0xFF11141E)
            : theme.surfaceCard.withValues(alpha: 0.88));

    final borderColor = isOperator
        ? theme.accentSecondary.withValues(alpha: 0.55)
        : (theme.isDark
            ? const Color(0xFF22293C)
            : theme.borderSubtle.withValues(alpha: 0.8));

    final textColor = isOperator
        ? theme.accentSecondary
        : theme.textPrimary;

    return SpringBounceTap(
      onTap: () => _onKeyPress(key),
      pressedScale: 0.92,
      bounceOvershoot: 1.06,
      child: LiquidGlassContainer(
        blur: 14,
        borderRadius: BorderRadius.circular(16),
        backgroundColor: bgColor,
        borderColor: borderColor,
        borderWidth: 1.1,
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
          if (isOperator)
            BoxShadow(
              color: theme.accentSecondary.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 1),
            ),
        ],
        child: Center(
          child: Text(
            key.label,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnterButton(PhonePadThemeData theme) {
    return SpringBounceTap(
      onTap: () => _onKeyPress(NumpadKey.enter),
      pressedScale: 0.94,
      bounceOvershoot: 1.05,
      child: LiquidGlassContainer(
        blur: 16,
        borderRadius: BorderRadius.circular(18),
        backgroundColor: theme.accentPrimary.withValues(alpha: 0.95),
        borderGradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.6),
            theme.accentPrimary.withValues(alpha: 0.8),
          ],
        ),
        shadows: [
          BoxShadow(
            color: theme.accentPrimary.withValues(alpha: 0.45),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.keyboard_return_rounded,
                size: 20,
                color: theme.isDark ? Colors.black : Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                'ENTER',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: theme.isDark ? Colors.black : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
