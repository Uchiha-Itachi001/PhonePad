import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/network/transport.dart';
import '../../../core/protocol/keys.dart';
import '../../../core/protocol/opcode.dart';
import '../../../core/protocol/packet.dart';
import '../../../core/theme/spring_bounce_tap.dart';
import '../../../core/theme/theme_controller.dart';

/// Full-featured tactile QWERTY keyboard with numbers, symbols, modifiers,
/// quick shortcuts, and mobile system keyboard bridge.
class KeyboardDeck extends StatefulWidget {
  final ITransport transport;
  final VoidCallback onActivity;
  final ValueChanged<String> onKeyNameChanged;

  const KeyboardDeck({
    super.key,
    required this.transport,
    required this.onActivity,
    required this.onKeyNameChanged,
  });

  @override
  State<KeyboardDeck> createState() => _KeyboardDeckState();
}

class _KeyboardDeckState extends State<KeyboardDeck> {
  bool _isShifted = false;
  bool _isCapsLock = false;
  bool _isSymbols = false;
  bool _isExtraSymbols = false;
  DateTime _lastShiftTap = DateTime.fromMillisecondsSinceEpoch(0);

  // Hidden IME controller for system keyboard input
  final FocusNode _imeFocusNode = FocusNode();
  final TextEditingController _imeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _imeController.addListener(_onImeTextChanged);
  }

  @override
  void dispose() {
    _imeController.removeListener(_onImeTextChanged);
    _imeController.dispose();
    _imeFocusNode.dispose();
    super.dispose();
  }

  void _onImeTextChanged() {
    final text = _imeController.text;
    if (text.isNotEmpty) {
      widget.onActivity();
      for (final char in text.characters) {
        _sendChar(char);
      }
      _imeController.clear();
    }
  }

  void _sendChar(String char) {
    widget.onActivity();
    HapticFeedback.lightImpact();
    widget.onKeyNameChanged(char);

    for (final unit in char.codeUnits) {
      widget.transport.sendPacket(PhonePadPacket(
        opcode: Opcode.keyboard,
        dx: unit,
        dy: KeyboardKeyType.unicodeChar,
      ));
    }
  }

  void _sendSpecialKey(SpecialKey key) {
    widget.onActivity();
    HapticFeedback.mediumImpact();
    widget.onKeyNameChanged(key.label);

    widget.transport.sendPacket(PhonePadPacket(
      opcode: Opcode.keyboard,
      dx: key.code,
      dy: KeyboardKeyType.specialKey,
    ));
  }

  void _sendShortcut(ShortcutKey shortcut) {
    widget.onActivity();
    HapticFeedback.mediumImpact();
    widget.onKeyNameChanged(shortcut.combo);

    widget.transport.sendPacket(PhonePadPacket(
      opcode: Opcode.keyboard,
      dx: shortcut.code,
      dy: KeyboardKeyType.shortcut,
    ));
  }

  void _onShiftTap() {
    widget.onActivity();
    HapticFeedback.mediumImpact();
    final now = DateTime.now();
    final isDoubleTap = now.difference(_lastShiftTap).inMilliseconds < 300;
    _lastShiftTap = now;

    setState(() {
      if (_isCapsLock) {
        _isCapsLock = false;
        _isShifted = false;
        widget.onKeyNameChanged('SHIFT OFF');
      } else if (isDoubleTap) {
        _isCapsLock = true;
        _isShifted = true;
        widget.onKeyNameChanged('CAPS LOCK');
      } else {
        _isShifted = !_isShifted;
        widget.onKeyNameChanged(_isShifted ? 'SHIFT' : 'SHIFT OFF');
      }
    });
  }

  void _onLetterTap(String letter) {
    final char = (_isShifted || _isCapsLock) ? letter.toUpperCase() : letter.toLowerCase();
    _sendChar(char);

    if (_isShifted && !_isCapsLock) {
      setState(() {
        _isShifted = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final theme = ThemeController.instance.theme;

        return Stack(
          children: [
            // Invisible IME bridge for hardware or system on-screen keyboard
            Positioned(
              left: -999,
              top: -999,
              width: 1,
              height: 1,
              child: Opacity(
                opacity: 0,
                child: TextField(
                  focusNode: _imeFocusNode,
                  controller: _imeController,
                  autocorrect: false,
                  enableSuggestions: true,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) {
                    _sendSpecialKey(SpecialKey.enter);
                    _imeFocusNode.requestFocus();
                  },
                ),
              ),
            ),

            // Visible tactile keyboard deck
            Column(
              children: [
                // Top utility & shortcuts action bar
                _buildActionBar(theme),
                const SizedBox(height: 4),

                // Responsive Key Rows
                Expanded(
                  child: _isSymbols
                      ? _buildSymbolsRows(theme)
                      : _buildQwertyRows(theme),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionBar(PhonePadThemeData theme) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: theme.surfaceCard.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _buildActionButton(
            label: 'ESC',
            onTap: () => _sendSpecialKey(SpecialKey.escape),
            theme: theme,
          ),
          _buildActionButton(
            label: 'TAB',
            onTap: () => _sendSpecialKey(SpecialKey.tab),
            theme: theme,
          ),
          _buildActionButton(
            label: 'ALL',
            subLabel: 'Ctrl+A',
            onTap: () => _sendShortcut(ShortcutKey.selectAll),
            theme: theme,
          ),
          _buildActionButton(
            label: 'COPY',
            subLabel: 'Ctrl+C',
            onTap: () => _sendShortcut(ShortcutKey.copy),
            theme: theme,
          ),
          _buildActionButton(
            label: 'PASTE',
            subLabel: 'Ctrl+V',
            onTap: () => _sendShortcut(ShortcutKey.paste),
            theme: theme,
          ),
          _buildActionButton(
            label: 'UNDO',
            subLabel: 'Ctrl+Z',
            onTap: () => _sendShortcut(ShortcutKey.undo),
            theme: theme,
          ),
          _buildActionButton(
            label: 'SAVE',
            subLabel: 'Ctrl+S',
            onTap: () => _sendShortcut(ShortcutKey.save),
            theme: theme,
          ),
          _buildActionButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => _sendSpecialKey(SpecialKey.arrowLeft),
            theme: theme,
          ),
          _buildActionButton(
            icon: Icons.arrow_upward_rounded,
            onTap: () => _sendSpecialKey(SpecialKey.arrowUp),
            theme: theme,
          ),
          _buildActionButton(
            icon: Icons.arrow_downward_rounded,
            onTap: () => _sendSpecialKey(SpecialKey.arrowDown),
            theme: theme,
          ),
          _buildActionButton(
            icon: Icons.arrow_forward_rounded,
            onTap: () => _sendSpecialKey(SpecialKey.arrowRight),
            theme: theme,
          ),
          // System keyboard summon button
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                HapticFeedback.selectionClick();
                _imeFocusNode.requestFocus();
                widget.onKeyNameChanged('SYSTEM IME');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.accentPrimary.withValues(alpha: 0.25),
                      theme.accentSecondary.withValues(alpha: 0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.accentPrimary.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.keyboard_alt_rounded,
                      size: 14,
                      color: theme.accentPrimary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'IME',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: theme.accentPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    String? label,
    String? subLabel,
    IconData? icon,
    required VoidCallback onTap,
    required PhonePadThemeData theme,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        splashColor: theme.accentPrimary.withValues(alpha: 0.2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: theme.surfaceCard.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.borderSubtle),
          ),
          child: Center(
            child: icon != null
                ? Icon(icon, size: 14, color: theme.textSecondary)
                : Text(
                    label ?? '',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: theme.textSecondary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildFunctionKeyRow(PhonePadThemeData theme) {
    const fKeys = [
      (SpecialKey.f1, 'F1'),
      (SpecialKey.f2, 'F2'),
      (SpecialKey.f3, 'F3'),
      (SpecialKey.f4, 'F4'),
      (SpecialKey.f5, 'F5'),
      (SpecialKey.f6, 'F6'),
      (SpecialKey.f7, 'F7'),
      (SpecialKey.f8, 'F8'),
      (SpecialKey.f9, 'F9'),
      (SpecialKey.f10, 'F10'),
      (SpecialKey.f11, 'F11'),
      (SpecialKey.f12, 'F12'),
    ];

    return Expanded(
      child: Row(
        children: [
          Expanded(
            flex: 10,
            child: Padding(
              padding: const EdgeInsets.all(1.5),
              child: _buildSpecialKeyButton(
                label: 'Esc',
                fontSize: 10.5,
                onTap: () => _sendSpecialKey(SpecialKey.escape),
                theme: theme,
              ),
            ),
          ),
          ...fKeys.map((f) => Expanded(
            flex: 7,
            child: Padding(
              padding: const EdgeInsets.all(1.5),
              child: _buildSpecialKeyButton(
                label: f.$2,
                fontSize: 10.0,
                onTap: () => _sendSpecialKey(f.$1),
                theme: theme,
              ),
            ),
          )),
          Expanded(
            flex: 10,
            child: Padding(
              padding: const EdgeInsets.all(1.5),
              child: _buildSpecialKeyButton(
                label: 'Del',
                fontSize: 10.5,
                onTap: () => _sendSpecialKey(SpecialKey.delete),
                theme: theme,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQwertyRows(PhonePadThemeData theme) {
    const row1 = ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'];
    const row2 = ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'];
    const row3 = ['z', 'x', 'c', 'v', 'b', 'n', 'm'];

    return Column(
      children: [
        // Function Keys Row (Esc, F1 - F12, Del)
        _buildFunctionKeyRow(theme),

        // Row 1
        Expanded(
          child: Row(
            children: row1.map((l) {
              final display = (_isShifted || _isCapsLock) ? l.toUpperCase() : l;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: _buildKey(
                    label: display,
                    onTap: () => _onLetterTap(l),
                    theme: theme,
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Row 2
        Expanded(
          child: Row(
            children: [
              const Spacer(flex: 1),
              ...row2.map((l) {
                final display = (_isShifted || _isCapsLock) ? l.toUpperCase() : l;
                return Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: _buildKey(
                      label: display,
                      onTap: () => _onLetterTap(l),
                      theme: theme,
                    ),
                  ),
                );
              }),
              const Spacer(flex: 1),
            ],
          ),
        ),

        // Row 3 (Shift, Z..M, Backspace)
        Expanded(
          child: Row(
            children: [
              // Shift Key
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: _buildSpecialKeyButton(
                    icon: _isCapsLock
                        ? Icons.keyboard_capslock_rounded
                        : Icons.arrow_upward_rounded,
                    isActive: _isShifted || _isCapsLock,
                    activeColor: theme.accentPrimary,
                    onTap: _onShiftTap,
                    theme: theme,
                  ),
                ),
              ),
              ...row3.map((l) {
                final display = (_isShifted || _isCapsLock) ? l.toUpperCase() : l;
                return Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: _buildKey(
                      label: display,
                      onTap: () => _onLetterTap(l),
                      theme: theme,
                    ),
                  ),
                );
              }),
              // Backspace Key
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: _buildSpecialKeyButton(
                    icon: Icons.backspace_outlined,
                    onTap: () => _sendSpecialKey(SpecialKey.backspace),
                    theme: theme,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Row 4 (Symbols, Space, Dot/Comma, Enter)
        Expanded(
          child: Row(
            children: [
              // ?123 Mode Toggle
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: _buildSpecialKeyButton(
                    label: '?123',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _isSymbols = true;
                        _isExtraSymbols = false;
                      });
                    },
                    theme: theme,
                  ),
                ),
              ),
              // Comma
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: _buildKey(
                    label: ',',
                    onTap: () => _sendChar(','),
                    theme: theme,
                  ),
                ),
              ),
              // Spacebar
              Expanded(
                flex: 8,
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: _buildSpaceBar(theme),
                ),
              ),
              // Period
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: _buildKey(
                    label: '.',
                    onTap: () => _sendChar('.'),
                    theme: theme,
                  ),
                ),
              ),
              // Enter Key
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: _buildEnterKey(theme),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSymbolsRows(PhonePadThemeData theme) {
    const numRow = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];
    final symRow1 = _isExtraSymbols
        ? ['~', '`', '|', '•', '√', 'π', '÷', '×', '§', 'Δ']
        : ['@', '#', '\$', '%', '&', '*', '-', '+', '(', ')'];

    final symRow2 = _isExtraSymbols
        ? ['£', '€', '¥', '¢', '^', '°', '=', '{', '}', '\\']
        : ['!', '"', '\'', ':', ';', '/', '?', '_', '<', '>'];

    return Column(
      children: [
        // Function Keys Row (Esc, F1 - F12, Del)
        _buildFunctionKeyRow(theme),

        // Numbers row
        Expanded(
          child: Row(
            children: numRow.map((n) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: _buildKey(
                    label: n,
                    onTap: () => _sendChar(n),
                    theme: theme,
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Symbols Row 1
        Expanded(
          child: Row(
            children: symRow1.map((s) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: _buildKey(
                    label: s,
                    onTap: () => _sendChar(s),
                    theme: theme,
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Symbols Row 2 (More symbols toggle, symbols, backspace)
        Expanded(
          child: Row(
            children: [
              // Extra symbols toggle (=/<)
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: _buildSpecialKeyButton(
                    label: _isExtraSymbols ? '1/2' : '=\\<',
                    isActive: _isExtraSymbols,
                    activeColor: theme.accentSecondary,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _isExtraSymbols = !_isExtraSymbols;
                      });
                    },
                    theme: theme,
                  ),
                ),
              ),
              ...symRow2.map((s) {
                return Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: _buildKey(
                      label: s,
                      onTap: () => _sendChar(s),
                      theme: theme,
                    ),
                  ),
                );
              }),
              // Backspace
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: _buildSpecialKeyButton(
                    icon: Icons.backspace_outlined,
                    onTap: () => _sendSpecialKey(SpecialKey.backspace),
                    theme: theme,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Row 4 (ABC toggle, Space, Enter)
        Expanded(
          child: Row(
            children: [
              // ABC Toggle
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: _buildSpecialKeyButton(
                    label: 'ABC',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _isSymbols = false;
                        _isExtraSymbols = false;
                      });
                    },
                    theme: theme,
                  ),
                ),
              ),
              // Slash / Underscore
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: _buildKey(
                    label: '/',
                    onTap: () => _sendChar('/'),
                    theme: theme,
                  ),
                ),
              ),
              // Spacebar
              Expanded(
                flex: 8,
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: _buildSpaceBar(theme),
                ),
              ),
              // Period
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: _buildKey(
                    label: '.',
                    onTap: () => _sendChar('.'),
                    theme: theme,
                  ),
                ),
              ),
              // Enter Key
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: _buildEnterKey(theme),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKey({
    required String label,
    required VoidCallback onTap,
    required PhonePadThemeData theme,
  }) {
    return SpringBounceTap(
      onTap: onTap,
      pressedScale: 0.90,
      bounceOvershoot: 1.07,
      child: Container(
        decoration: BoxDecoration(
          color: theme.surfaceCard.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.borderSubtle, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 3,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialKeyButton({
    String? label,
    IconData? icon,
    bool isActive = false,
    Color? activeColor,
    double? fontSize,
    bool isHero = false,
    required VoidCallback onTap,
    required PhonePadThemeData theme,
  }) {
    final effectiveActiveColor = isHero ? theme.accentPrimary : (activeColor ?? theme.accentPrimary);
    final bgColor = isHero
        ? theme.accentPrimary.withValues(alpha: 0.28)
        : (isActive
            ? effectiveActiveColor.withValues(alpha: 0.2)
            : theme.accentSecondary.withValues(alpha: 0.12));

    final borderColor = isHero
        ? theme.accentPrimary.withValues(alpha: 0.75)
        : (isActive
            ? effectiveActiveColor.withValues(alpha: 0.6)
            : theme.borderSubtle);

    final contentColor = isHero
        ? theme.accentPrimary
        : (isActive
            ? effectiveActiveColor
            : theme.textSecondary);

    return SpringBounceTap(
      onTap: onTap,
      pressedScale: 0.90,
      bounceOvershoot: 1.07,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1.0),
        ),
        child: Center(
          child: icon != null
              ? Icon(icon, size: 18, color: contentColor)
              : Text(
                  label ?? '',
                  style: TextStyle(
                    fontSize: fontSize ?? 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: contentColor,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSpaceBar(PhonePadThemeData theme) {
    return SpringBounceTap(
      onTap: () => _sendChar(' '),
      pressedScale: 0.95,
      bounceOvershoot: 1.04,
      child: Container(
        decoration: BoxDecoration(
          color: theme.surfaceCard.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.borderSubtle),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 3,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'SPACE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
              color: theme.textSecondary.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnterKey(PhonePadThemeData theme) {
    return SpringBounceTap(
      onTap: () => _sendSpecialKey(SpecialKey.enter),
      pressedScale: 0.92,
      bounceOvershoot: 1.06,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.accentPrimary,
              theme.accentPrimary.withValues(alpha: 0.85),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: theme.accentPrimary.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.keyboard_return_rounded,
                size: 16,
                color: theme.isDark ? Colors.black : Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
