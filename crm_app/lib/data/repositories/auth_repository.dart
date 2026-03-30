import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/storage_service.dart';
import '../models/user_model.dart';

class AuthRepository {
  final ApiClient _apiClient;
  final StorageService _storage;

  AuthRepository({
    required ApiClient apiClient,
    required StorageService storage,
  }) : _apiClient = apiClient,
       _storage = storage;

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      AppConstants.authLogin,
      data: {'email': email, 'password': password},
    );

    final authResponse = AuthResponse.fromJson(response.data);
    await _storage.saveToken(authResponse.token);
    await _storage.saveUserData(authResponse.user.toJson());
    return authResponse;
  }

  Future<void> logout() async {
    try {
      // Use a short timeout for logout - we don't need to wait for server response
      // We just need to clear local storage regardless of server response
      await _apiClient.post(
        AppConstants.authLogout,
        options: Options(
          sendTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
      );
    } catch (_) {
      // Ignore logout API errors - server might be slow or unreachable
      // We still want to clear local storage and log out
    } finally {
      await _storage.clearAll();
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _apiClient.post(
      AppConstants.authChangePassword,
      data: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  Future<User?> getCurrentUser() async {
    final userData = await _storage.getUserData();
    if (userData != null) {
      return User.fromJson(userData);
    }
    return null;
  }

  Future<void> persistUser(User user) async {
    await _storage.saveUserData(user.toJson());
  }

  Future<bool> isLoggedIn() async {
    return await _storage.isLoggedIn();
  }

  Future<String?> getToken() async {
    return await _storage.getToken();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final storage = ref.watch(storageServiceProvider);
  return AuthRepository(apiClient: apiClient, storage: storage);
});
