import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kDebugMode, kIsWeb;
import 'package:permission_handler/permission_handler.dart';

import '../../firebase_options.dart';
import 'fcm_data_message_display.dart';
import 'fcm_notification_consent.dart';
import 'notification_service.dart';

/// Firebase Cloud Messaging: real-time push alongside existing local notifications.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  bool _started = false;

  /// Refresh in-app notification list (and optionally show a tray from API) when FCM arrives
  /// while the app is foregrounded — set from [CRMApp] with Riverpod [WidgetRef].
  Future<void> Function(RemoteMessage message, bool showedTrayFromPayload)?
      _foregroundSideEffects;

  /// Register [CRMApp] callback (e.g. sync `/api/notifications` for attendance alerts). Clear on logout.
  void setForegroundSideEffects(
    Future<void> Function(RemoteMessage message, bool showedTrayFromPayload)?
        callback,
  ) {
    _foregroundSideEffects = callback;
  }

  /// After the user opts in to notifications in-app and OS permission is granted.
  Future<void> refreshFcmRegistrationIfPossible() async {
    if (!_started) return;
    try {
      await FirebaseMessaging.instance.getToken();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FCM getToken after user consent: $e');
      }
    }
  }

  /// Returns false if Firebase failed to start (app still runs on local notifications only).
  Future<bool> initialize() async {
    if (_started) return true;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } catch (e, st) {
      debugPrint('Firebase.initializeApp failed: $e\n$st');
      return false;
    }

    final messaging = FirebaseMessaging.instance;
    await messaging.setAutoInitEnabled(true);

    // Do not call [requestPermission] here — Apple requires in-app consent before the system
    // prompt (paired with notification settings defaulting off). See App Review Guideline 4.5.4.

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      if (kDebugMode) {
        debugPrint('FCM opened app: ${message.messageId}');
      }
      await _foregroundSideEffects?.call(message, false);
    });

    messaging.onTokenRefresh.listen((token) {
      if (kDebugMode) {
        debugPrint('FCM token refreshed (len=${token.length})');
      }
    });

    if (await _osAllowsPushPresentation()) {
      try {
        final token = await messaging.getToken();
        if (kDebugMode && token != null) {
          final t = token.length > 32 ? '${token.substring(0, 32)}…' : token;
          debugPrint('FCM token (register with your backend if needed): $t');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            'FCM getToken failed (expected until Firebase is configured): $e',
          );
        }
      }
    }

    _started = true;
    return true;
  }

  Future<bool> _osAllowsPushPresentation() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final s = await FirebaseMessaging.instance.getNotificationSettings();
      return s.authorizationStatus == AuthorizationStatus.authorized;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.notification.status;
      return status.isGranted;
    }
    return false;
  }

  Future<bool> _mayPresentForegroundTray() async {
    if (!await userOptedInToAppNotifications()) return false;
    return _osAllowsPushPresentation();
  }

  /// Cold start: user tapped a notification that launched the app. Call after auth + [setForegroundSideEffects].
  Future<void> handleInitialMessageOpenedApp() async {
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial == null) return;
    await _foregroundSideEffects?.call(initial, false);
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    // Prefer data fields; fall back to [RemoteMessage.notification].
    final parsed = FcmDataPayload.parseForForeground(message);
    var showedTray = false;
    if (parsed != null && await _mayPresentForegroundTray()) {
      final notifications = NotificationService();
      await notifications.initialize();
      await notifications.showFcmForegroundNotification(
        title: parsed.title,
        body: parsed.body,
        payload: message.data.isNotEmpty ? message.data.toString() : message.messageId,
      );
      showedTray = true;
    } else if (kDebugMode && parsed != null) {
      debugPrint(
        'FCM foreground: suppressed tray (no in-app + OS consent); will sync API '
        'dataKeys=${message.data.keys}',
      );
    } else if (kDebugMode) {
      debugPrint(
        'FCM foreground: no title/body in payload; will sync API '
        'dataKeys=${message.data.keys}',
      );
    }

    // Always: refresh `/api/notifications` so attendance rows created server-side appear;
    // if FCM was silent, show tray from fetched [NotificationItem].
    await _foregroundSideEffects?.call(message, showedTray);
  }
}
