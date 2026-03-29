import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Uses device vibrator when available (Android), else [HapticFeedback].
class AppHaptics {
  AppHaptics._();

  /// Single pulse when the hold gesture completes (bar full).
  static void holdComplete() {
    _pulse(60);
  }

  static void _pulse(int durationMs) {
    if (kIsWeb) {
      HapticFeedback.mediumImpact();
      return;
    }
    unawaited(_pulseAsync(durationMs));
  }

  static Future<void> _pulseAsync(int durationMs) async {
    try {
      final has = await Vibration.hasVibrator();
      if (has == true) {
        await Vibration.vibrate(duration: durationMs);
        return;
      }
    } catch (_) {}
    HapticFeedback.mediumImpact();
  }
}
