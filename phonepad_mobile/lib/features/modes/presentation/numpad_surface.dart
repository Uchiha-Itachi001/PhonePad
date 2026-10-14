import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/network/transport.dart';
import '../../../core/protocol/keys.dart';
import '../../../core/protocol/opcode.dart';
import '../../../core/protocol/packet.dart';
import '../../../core/theme/liquid_glass_container.dart';
import '../../../core/theme/spring_bounce_tap.dart';
import '../../../core/theme/theme_controller.dart';
import 'keyboard_deck.dart';

/// Virtual 10-key numeric keypad and QWERTY keyboard with glassmorphic tactile keys.
class NumpadSurface extends StatefulWidget {
  final ITransport transport;
  final VoidCallback onActivity;

  const NumpadSurface({
    super.key,
    required this.transport,
    required this.onActivity,
  });

  @override
  State<NumpadSurface> createState() => _NumpadSurfaceState();
}

class _NumpadSurfaceState extends State<NumpadSurface> {
  String _lastPressedKey = 'READY';
  bool _isKeyboardMode = false;

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
          color: theme.backgroundPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: OrientationBuilder(
            builder: (context, orientation) {
              final isLandscape = orientation == Orientation.landscape;

              if (isLandscape) {
                return _buildLandscapeLayout(theme);
              }
              return _buildPortraitLayout(theme);
            },
          ),
        );
      },
    );
  }

  Widget _buildPortraitLayout(PhonePadThemeData theme) {
    if (_isKeyboardMode) {
      return Column(
        children: [
          _buildTelemetryHeader(theme),
          const SizedBox(height: 8),
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

    const gridKeys = [
      [NumpadKey.num7, NumpadKey.num8, NumpadKey.num9, NumpadKey.divide],
      [NumpadKey.num4, NumpadKey.num5, NumpadKey.num6, NumpadKey.multiply],
      [NumpadKey.num1, NumpadKey.num2, NumpadKey.num3, NumpadKey.subtract],
      [NumpadKey.num0, NumpadKey.decimal, NumpadKey.backspace, NumpadKey.add],
    ];

    return Column(
      children: [
        // Top telemetry status strip
        _buildTelemetryHeader(theme),
        const SizedBox(height: 8),

        // 4x4 Key Grid
        Expanded(
          child: Column(
            children: gridKeys.map((row) {
              return Expanded(
                child: Row(
                  children: row.map((key) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: _buildNumpadButton(key, theme),
                      ),
                    );
                  }).toList(),
                ),
              );
            }).toList(),
          ),
        ),

        // Glowing Hero Enter Key
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: _buildEnterButton(theme),
          ),
        ),
      ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.surfaceCard.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Segmented Deck Switcher (123 NUMPAD vs KEYBOARD)
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: theme.surfaceCard.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.borderSubtle),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModeTab(
                  label: '123',
                  fullLabel: '123 NUMPAD',
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
                _buildModeTab(
                  label: 'QWERTY',
                  fullLabel: 'KEYBOARD',
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
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.accentPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
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
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required String label,
    required String fullLabel,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required PhonePadThemeData theme,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.accentPrimary.withValues(alpha: 0.22)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? theme.accentPrimary.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected ? theme.accentPrimary : theme.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                fullLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: isSelected ? theme.accentPrimary : theme.textSecondary,
                ),
              ),
            ],
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
        ? theme.accentSecondary.withValues(alpha: 0.14)
        : theme.surfaceCard.withValues(alpha: 0.88);

    final borderColor = isOperator
        ? theme.accentSecondary.withValues(alpha: 0.45)
        : theme.borderSubtle.withValues(alpha: 0.8);

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
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 6,
            offset: const Offset(0, 2),
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
            Colors.white.withValues(alpha: 0.5),
            theme.accentPrimary.withValues(alpha: 0.7),
          ],
        ),
        shadows: [
          BoxShadow(
            color: theme.accentPrimary.withValues(alpha: 0.4),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.keyboard_return_rounded,
                size: 18,
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
