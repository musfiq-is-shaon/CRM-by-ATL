import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../firebase_options.dart';
import 'fcm_data_message_display.dart';
import 'fcm_notification_consent.dart';

/// Must be a top-level function; registered before [runApp].
///
/// **Data-only** messages (`data.title` / `data.body`, no `notification` block) do not
/// show a system notification by themselves — we display them with
/// [showFcmDataMessageAsLocalNotification] (same as production apps using silent push + local UI).
///
/// **Server (FCM HTTP v1):** For delivery while the app is **terminated**, Android requires
/// `android.priority` = **HIGH** (and avoid "force stop" / OEM battery kill). Notification
/// payloads (`notification` block) are shown by the OS when the app is killed; data-only
/// relies on this handler + local notifications.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  if (kDebugMode) {
    debugPrint(
      'FCM background data keys=${message.data.keys} '
      'messageId=${message.messageId}',
    );
  }
  if (!await userOptedInToAppNotifications()) {
    if (kDebugMode) {
      debugPrint('FCM background: skip show — user has not enabled notifications in-app');
    }
    return;
  }
  await showFcmDataMessageAsLocalNotification(message);
}
