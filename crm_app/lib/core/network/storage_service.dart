import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

/// One saved login row (secure storage).
class SavedLoginAccount {
  final String email;
  final String password;

  const SavedLoginAccount({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
      };

  factory SavedLoginAccount.fromJson(Map<String, dynamic> m) {
    return SavedLoginAccount(
      email: (m['email'] ?? '').toString(),
      password: (m['password'] ?? '').toString(),
    );
  }
}

class StorageService {
  static const int _maxSavedAccounts = 10;

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

  /// Clears auth session only; keeps saved login accounts.
  Future<void> clearSession() async {
    await Future.wait([
      clearToken(),
      clearUserData(),
      _storage.delete(key: AppConstants.refreshTokenKey),
    ]);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  Future<void> _clearLegacyRememberedKeysOnly() async {
    await Future.wait([
      _storage.delete(key: AppConstants.rememberMeEnabledKey),
      _storage.delete(key: AppConstants.rememberedEmailKey),
      _storage.delete(key: AppConstants.rememberedPasswordKey),
    ]);
  }

  Future<void> _migrateLegacyRememberedLogin() async {
    final existing = await _storage.read(key: AppConstants.savedLoginAccountsKey);
    if (existing != null && existing.isNotEmpty) return;

    final flag = await _storage.read(key: AppConstants.rememberMeEnabledKey);
    if (flag != 'true') return;

    final email = await _storage.read(key: AppConstants.rememberedEmailKey);
    final password = await _storage.read(key: AppConstants.rememberedPasswordKey);
    await _clearLegacyRememberedKeysOnly();
    if (email == null || email.trim().isEmpty) return;

    await _writeAccountsList([
      SavedLoginAccount(email: email.trim(), password: password ?? ''),
    ]);
  }

  Future<List<SavedLoginAccount>> _readAccountsListRaw() async {
    final raw = await _storage.read(key: AppConstants.savedLoginAccountsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => SavedLoginAccount.fromJson(Map<String, dynamic>.from(e)))
          .where((a) => a.email.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeAccountsList(List<SavedLoginAccount> list) async {
    await _storage.write(
      key: AppConstants.savedLoginAccountsKey,
      value: jsonEncode(list.map((a) => a.toJson()).toList()),
    );
  }

  /// All accounts the user saved with “Remember me” (newest last).
  Future<List<SavedLoginAccount>> getSavedAccounts() async {
    await _migrateLegacyRememberedLogin();
    return _readAccountsListRaw();
  }

  /// Add or update account (matched by email, case-insensitive). Caps list size.
  Future<void> upsertSavedAccount(String email, String password) async {
    await _migrateLegacyRememberedLogin();
    final trimmed = email.trim();
    if (trimmed.isEmpty) return;

    var list = await _readAccountsListRaw();
    final key = trimmed.toLowerCase();
    list.removeWhere((a) => a.email.trim().toLowerCase() == key);
    list.add(SavedLoginAccount(email: trimmed, password: password));
    if (list.length > _maxSavedAccounts) {
      list = list.sublist(list.length - _maxSavedAccounts);
    }
    await _writeAccountsList(list);
  }

  /// Remove one saved account (e.g. user logged in with Remember me off).
  Future<void> removeSavedAccount(String email) async {
    await _migrateLegacyRememberedLogin();
    final key = email.trim().toLowerCase();
    if (key.isEmpty) return;
    final list = await _readAccountsListRaw();
    list.removeWhere((a) => a.email.trim().toLowerCase() == key);
    if (list.isEmpty) {
      await _storage.delete(key: AppConstants.savedLoginAccountsKey);
    } else {
      await _writeAccountsList(list);
    }
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
