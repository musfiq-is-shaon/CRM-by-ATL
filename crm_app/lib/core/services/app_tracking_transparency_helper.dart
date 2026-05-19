import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kDebugMode, kIsWeb;

/// App Store Guideline 5.1.2(i): if App Store Connect declares tracking, iOS must
/// show the App Tracking Transparency prompt before tracking-related collection.
///
/// Note: Apple’s “tracking” is **not** the same as GPS for attendance; location still
/// uses the Location permission dialogs. ATT controls the **advertising identifier**
/// (cross-app/website tracking). Call this once early so reviewers see the prompt.
Future<void> requestAppTrackingTransparencyIfNeeded() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
  try {
    // Avoid stacking on top of the first system dialog frame.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status == TrackingStatus.notDetermined) {
      await AppTrackingTransparency.requestTrackingAuthorization();
    }
    if (kDebugMode) {
      debugPrint('ATT status: ${await AppTrackingTransparency.trackingAuthorizationStatus}');
    }
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('ATT request skipped: $e\n$st');
    }
  }
}
