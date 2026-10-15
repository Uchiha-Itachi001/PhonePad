import 'dart:async';
import 'package:flutter/foundation.dart';

/// Power and screen governor optimizing AMOLED battery life.
class PowerGovernor extends ChangeNotifier {
  static final PowerGovernor instance = PowerGovernor();

  bool _isEnabled = true;
  int _timeoutSeconds = 60;
  DateTime _lastActiveTime = DateTime.now();
  bool _isDimmed = false;
  Timer? _checkTimer;

  PowerGovernor({
    Duration idleThreshold = const Duration(minutes: 1),
  }) : _timeoutSeconds = idleThreshold.inSeconds;

  bool get isEnabled => _isEnabled;
  int get timeoutSeconds => _timeoutSeconds;
  bool get isDimmed => _isEnabled && _isDimmed;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    if (_checkTimer == null && _isEnabled && _timeoutSeconds > 0) {
      _startTimer();
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      _checkTimer?.cancel();
      _checkTimer = null;
    }
  }

  void setEnabled(bool enabled) {
    if (_isEnabled != enabled) {
      _isEnabled = enabled;
      if (!enabled && _isDimmed) {
        _isDimmed = false;
      }
      if (enabled && hasListeners && _checkTimer == null) {
        _startTimer();
      } else if (!enabled) {
        _checkTimer?.cancel();
        _checkTimer = null;
      }
      notifyListeners();
    }
  }

  void setTimeoutSeconds(int seconds) {
    if (_timeoutSeconds != seconds) {
      _timeoutSeconds = seconds;
      _lastActiveTime = DateTime.now();
      _isDimmed = false;
      if (_timeoutSeconds > 0 && hasListeners && _checkTimer == null) {
        _startTimer();
      } else if (_timeoutSeconds <= 0) {
        _checkTimer?.cancel();
        _checkTimer = null;
      }
      notifyListeners();
    }
  }

  void _startTimer() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isEnabled || _timeoutSeconds <= 0) return;
      final elapsed = DateTime.now().difference(_lastActiveTime);
      if (elapsed.inSeconds >= _timeoutSeconds && !_isDimmed) {
        _isDimmed = true;
        notifyListeners();
      }
    });
  }

  /// Registers user touch interaction, instantly restoring full screen luminance in 0ms.
  void recordActivity() {
    _lastActiveTime = DateTime.now();
    if (_isDimmed) {
      _isDimmed = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    _checkTimer = null;
    super.dispose();
  }
}
