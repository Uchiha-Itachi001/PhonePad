import 'package:flutter/material.dart';

enum AppThemeId {
  electricBlue,
  obsidianEmerald,
  cyberpunkViolet,
  nordicIce,
  amoledPure,
  studioLight,
}

enum DotMatrixDensity {
  ultraDense(10.0, 1.0, 4.2, 'Ultra-Dense', '10px fine micro-digitizer'),
  dense(13.0, 1.2, 4.8, 'Precision Dense', '13px Samsung One UI dense grid'),
  balanced(18.0, 1.4, 5.2, 'Balanced', '18px standard spacing'),
  ambient(24.0, 1.6, 5.6, 'Ambient', '24px sparse clean dots');

  final double spacing;
  final double baseRadius;
  final double maxRadius;
  final String label;
  final String description;

  const DotMatrixDensity(
    this.spacing,
    this.baseRadius,
    this.maxRadius,
    this.label,
    this.description,
  );
}

class PhonePadThemeData {
  final AppThemeId id;
  final String name;
  final String subtitle;
  final Color backgroundPrimary;
  final Color backgroundSecondary;
  final Color surfaceCard;
  final Color accentPrimary;
  final Color accentSecondary;
  final Color accentTertiary;
  final Color textPrimary;
  final Color textSecondary;
  final Color borderSubtle;
  final Color dotBaseColor;
  final bool isDark;

  const PhonePadThemeData({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.backgroundPrimary,
    required this.backgroundSecondary,
    required this.surfaceCard,
    required this.accentPrimary,
    required this.accentSecondary,
    required this.accentTertiary,
    required this.textPrimary,
    required this.textSecondary,
    required this.borderSubtle,
    required this.dotBaseColor,
    required this.isDark,
  });

  static const PhonePadThemeData electricBlue = PhonePadThemeData(
    id: AppThemeId.electricBlue,
    name: 'Electric Blue',
    subtitle: 'Deep obsidian void & glowing electric blue',
    backgroundPrimary: Color(0xFF000000),
    backgroundSecondary: Color(0xFF000000),
    surfaceCard: Color(0xFF0E1118),
    accentPrimary: Color(0xFF007AFF),
    accentSecondary: Color(0xFF00E5FF),
    accentTertiary: Color(0xFF6366F1),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFF94A3B8),
    borderSubtle: Color(0x1AFFFFFF),
    dotBaseColor: Color(0x0E007AFF),
    isDark: true,
  );

  static const PhonePadThemeData obsidianEmerald = PhonePadThemeData(
    id: AppThemeId.obsidianEmerald,
    name: 'Obsidian Emerald',
    subtitle: 'Samsung One UI dark void & neon emerald',
    backgroundPrimary: Color(0xFF070C14),
    backgroundSecondary: Color(0xFF0B111C),
    surfaceCard: Color(0xFF101927),
    accentPrimary: Color(0xFF10B981),
    accentSecondary: Color(0xFF00E5FF),
    accentTertiary: Color(0xFFA855F7),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFF94A3B8),
    borderSubtle: Color(0x1AFFFFFF),
    dotBaseColor: Color(0x0CFFFFFF),
    isDark: true,
  );

  static const PhonePadThemeData cyberpunkViolet = PhonePadThemeData(
    id: AppThemeId.cyberpunkViolet,
    name: 'Cyberpunk Neon',
    subtitle: 'Electric violet & radiant magenta glow',
    backgroundPrimary: Color(0xFF090514),
    backgroundSecondary: Color(0xFF130924),
    surfaceCard: Color(0xFF1D0E38),
    accentPrimary: Color(0xFFA855F7),
    accentSecondary: Color(0xFFEC4899),
    accentTertiary: Color(0xFF38BDF8),
    textPrimary: Color(0xFFFAF5FF),
    textSecondary: Color(0xFFA8A29E),
    borderSubtle: Color(0x28A855F7),
    dotBaseColor: Color(0x0EC084FC),
    isDark: true,
  );

  static const PhonePadThemeData nordicIce = PhonePadThemeData(
    id: AppThemeId.nordicIce,
    name: 'Nordic Slate',
    subtitle: 'Deep oceanic slate & glacier sky blue',
    backgroundPrimary: Color(0xFF0B132B),
    backgroundSecondary: Color(0xFF1C2541),
    surfaceCard: Color(0xFF232F55),
    accentPrimary: Color(0xFF38BDF8),
    accentSecondary: Color(0xFF34D399),
    accentTertiary: Color(0xFF818CF8),
    textPrimary: Color(0xFFF0F9FF),
    textSecondary: Color(0xFF94A3B8),
    borderSubtle: Color(0x2438BDF8),
    dotBaseColor: Color(0x0E7DD3FC),
    isDark: true,
  );

  static const PhonePadThemeData amoledPure = PhonePadThemeData(
    id: AppThemeId.amoledPure,
    name: 'AMOLED True Black',
    subtitle: 'Zero-power pure black & electric lime',
    backgroundPrimary: Color(0xFF000000),
    backgroundSecondary: Color(0xFF080808),
    surfaceCard: Color(0xFF121212),
    accentPrimary: Color(0xFF84CC16),
    accentSecondary: Color(0xFF22D3EE),
    accentTertiary: Color(0xFFF59E0B),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF71717A),
    borderSubtle: Color(0x26FFFFFF),
    dotBaseColor: Color(0x0CFFFFFF),
    isDark: true,
  );

  static const PhonePadThemeData studioLight = PhonePadThemeData(
    id: AppThemeId.studioLight,
    name: 'Studio Porcelain',
    subtitle: 'Crisp clean daylight studio & deep indigo',
    backgroundPrimary: Color(0xFFF1F5F9),
    backgroundSecondary: Color(0xFFFFFFFF),
    surfaceCard: Color(0xFFE2E8F0),
    accentPrimary: Color(0xFF4F46E5),
    accentSecondary: Color(0xFF0284C7),
    accentTertiary: Color(0xFF059669),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    borderSubtle: Color(0x1E000000),
    dotBaseColor: Color(0x0C000000),
    isDark: false,
  );

  static const List<PhonePadThemeData> allThemes = [
    electricBlue,
    obsidianEmerald,
    cyberpunkViolet,
    nordicIce,
    amoledPure,
    studioLight,
  ];

  static PhonePadThemeData fromId(AppThemeId id) {
    switch (id) {
      case AppThemeId.electricBlue:
        return electricBlue;
      case AppThemeId.obsidianEmerald:
        return obsidianEmerald;
      case AppThemeId.cyberpunkViolet:
        return cyberpunkViolet;
      case AppThemeId.nordicIce:
        return nordicIce;
      case AppThemeId.amoledPure:
        return amoledPure;
      case AppThemeId.studioLight:
        return studioLight;
    }
  }
}

class ThemeController extends ChangeNotifier {
  static final ThemeController instance = ThemeController._();
  ThemeController._();

  PhonePadThemeData _currentTheme = PhonePadThemeData.electricBlue;
  DotMatrixDensity _dotDensity = DotMatrixDensity.dense;
  bool _twoFingerNavEnabled = true;
  bool _threeFingerSwitcherEnabled = true;
  bool _pinchZoomEnabled = true;
  double _motionSensitivity = 1.0;

  PhonePadThemeData get theme => _currentTheme;
  DotMatrixDensity get dotDensity => _dotDensity;
  bool get twoFingerNavEnabled => _twoFingerNavEnabled;
  bool get threeFingerSwitcherEnabled => _threeFingerSwitcherEnabled;
  bool get pinchZoomEnabled => _pinchZoomEnabled;
  double get motionSensitivity => _motionSensitivity;

  void setTheme(AppThemeId id) {
    if (_currentTheme.id != id) {
      _currentTheme = PhonePadThemeData.fromId(id);
      notifyListeners();
    }
  }

  void setDotDensity(DotMatrixDensity density) {
    if (_dotDensity != density) {
      _dotDensity = density;
      notifyListeners();
    }
  }

  void setTwoFingerNav(bool enabled) {
    if (_twoFingerNavEnabled != enabled) {
      _twoFingerNavEnabled = enabled;
      notifyListeners();
    }
  }

  void setThreeFingerSwitcher(bool enabled) {
    if (_threeFingerSwitcherEnabled != enabled) {
      _threeFingerSwitcherEnabled = enabled;
      notifyListeners();
    }
  }

  void setPinchZoom(bool enabled) {
    if (_pinchZoomEnabled != enabled) {
      _pinchZoomEnabled = enabled;
      notifyListeners();
    }
  }

  void setMotionSensitivity(double sensitivity) {
    _motionSensitivity = sensitivity;
    notifyListeners();
  }
}
