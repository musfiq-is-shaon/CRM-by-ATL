import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class StorageService {
  final FlutterSecureStorage _storage;

  StorageService({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  // Token Management
  Future<void> saveToken(String token) async {
    await _storage.write(key: AppConstants.tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: AppConstants.tokenKey);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: AppConstants.tokenKey);
  }

  // User Data
  Future<void> saveUserData(Map<String, dynamic> userData) async {
    await _storage.write(
      key: AppConstants.userKey,
      value: jsonEncode(userData),
    );
  }

  Future<Map<String, dynamic>?> getUserData() async {
    final data = await _storage.read(key: AppConstants.userKey);
    if (data != null) {
      return jsonDecode(data) as Map<String, dynamic>;
    }
    return null;
  }

  Future<void> clearUserData() async {
    await _storage.delete(key: AppConstants.userKey);
  }

  // Clear All
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  // Check if logged in
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // Notification Settings
  Future<void> saveNotificationSettings(Map<String, dynamic> settings) async {
    await _storage.write(
      key: 'notification_settings',
      value: jsonEncode(settings),
    );
  }

  Future<Map<String, dynamic>?> getNotificationSettings() async {
    final data = await _storage.read(key: 'notification_settings');
    if (data != null) {
      return jsonDecode(data) as Map<String, dynamic>;
    }
    return null;
  }
}

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});
