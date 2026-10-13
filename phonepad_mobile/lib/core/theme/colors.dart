import 'package:flutter/material.dart';

/// PhonePad Color Palette adhering to User Preference DNA.
abstract class PhonePadColors {
  /// Dark base background
  static const Color backgroundPrimary = Color(0xFF070C14);

  /// Secondary dark card/surface
  static const Color backgroundSecondary = Color(0xFF0B111C);

  /// Emerald main accent
  static const Color accentEmerald = Color(0xFF10B981);

  /// Teal secondary accent
  static const Color accentTeal = Color(0xFF14B8A6);

  /// Cyan highlight
  static const Color accentCyan = Color(0xFF06B6D4);

  /// Soft emerald ambient glow
  static const Color glowSoft = Color(0x6610B981);

  /// Strong active emerald glow
  static const Color glowActive = Color(0x9910B981);

  /// White text primary
  static const Color textPrimary = Color(0xFFF1F5F9);

  /// Subdued text secondary
  static const Color textSecondary = Color(0xFF94A3B8);

  /// Danger / disconnected red
  static const Color errorRed = Color(0xFFEF4444);
}
