import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/services/app_tracking_transparency_helper.dart';
import 'core/services/fcm_background.dart';
import 'core/services/fcm_service.dart';
import 'core/services/location_service.dart';
import 'core/services/notification_service.dart';
import 'firebase_options.dart';

void main() async {
  // Required before any plugin/async work (Firebase, FCM background handler, etc.).
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Optional — use --dart-define-from-file=.env or --dart-define instead.
  }

  // Must be registered before [runApp], as early as possible after binding init.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final notificationService = NotificationService();
  await notificationService.initialize();
  // OS notification consent is requested only after the user enables alerts in-app
  // (see [NotificationSettingsNotifier.setEnabled]) — App Store Review Guideline 4.5.4.

  await FcmService.instance.initialize();

  await requestAppTrackingTransparencyIfNeeded();

  final locationService = LocationService();
  await locationService.init();

  runApp(const ProviderScope(child: CRMApp()));
}
