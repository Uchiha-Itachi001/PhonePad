import 'package:flutter/material.dart';

/// PhonePad Color Palette adhering to User Preference DNA.
abstract class PhonePadColors {
  /// Dark base background
  static const Color backgroundPrimary = Color(0xFF000000);

  /// Secondary dark card/surface
  static const Color backgroundSecondary = Color(0xFF000000);

  /// Electric Blue main accent (Matches App Icon & Remote Deck Design)
  static const Color accentBlue = Color(0xFF007AFF);
  static const Color accentPrimary = Color(0xFF0084FF);

  /// Legacy emerald alias for backwards compatibility
  static const Color accentEmerald = Color(0xFF007AFF);

  /// Cyan secondary accent
  static const Color accentTeal = Color(0xFF00E5FF);
  static const Color accentCyan = Color(0xFF38BDF8);

  /// Soft electric blue ambient glow
  static const Color glowSoft = Color(0x66007AFF);

  /// Strong active electric blue glow
  static const Color glowActive = Color(0x99007AFF);

  /// White text primary
  static const Color textPrimary = Color(0xFFF1F5F9);

  /// Subdued text secondary
  static const Color textSecondary = Color(0xFF94A3B8);

  /// Success / connected vibrant green
  static const Color successGreen = Color(0xFF10B981);

  /// Danger / disconnected red
  static const Color errorRed = Color(0xFFEF4444);
}
