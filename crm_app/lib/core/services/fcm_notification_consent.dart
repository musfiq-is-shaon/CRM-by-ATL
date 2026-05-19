import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../json_parse.dart';

/// Reads the same secure-storage key as [StorageService] — safe from FCM background isolate
/// (no Riverpod). Defaults to **false** when missing so pushes are off until the user opts in.
Future<bool> userOptedInToAppNotifications() async {
  try {
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock,
      ),
    );
    final data = await storage.read(key: 'notification_settings');
    if (data == null || data.isEmpty) return false;
    final map = jsonDecode(data) as Map<String, dynamic>;
    return parseOptionalBool(map['enabled']) ?? false;
  } catch (_) {
    return false;
  }
}
