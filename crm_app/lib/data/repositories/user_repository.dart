import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../models/user_model.dart';

class UserRepository {
  final ApiClient _apiClient;

  // In-memory cache for users
  final Map<String, User> _userCache = {};
  List<User>? _cachedUsers;

  UserRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<List<User>> getUsers({bool forceRefresh = false}) async {
    // Return cached users if available and not forcing refresh
    if (!forceRefresh && _cachedUsers != null) {
      return _cachedUsers!;
    }

    final response = await _apiClient.get(AppConstants.users);
    final List<dynamic> data = response.data;
    final users = data.map((json) => User.fromJson(json)).toList();

    // Cache all users
    _cachedUsers = users;
    for (var user in users) {
      _userCache[user.id] = user;
    }

    return users;
  }

  Future<User?> getUserById(String id, {bool useCache = true}) async {
    // Return cached user if available
    if (useCache && _userCache.containsKey(id)) {
      return _userCache[id];
    }

    final response = await _apiClient.get('${AppConstants.users}/$id');
    final user = User.fromJson(response.data);
    _userCache[user.id] = user;
    return user;
  }

  /// Batch fetch multiple users by IDs - much more efficient than individual calls
  Future<Map<String, User>> getUsersByIds(List<String> ids) async {
    final result = <String, User>{};
    final idsToFetch = <String>[];

    // Check cache first
    for (var id in ids) {
      if (_userCache.containsKey(id)) {
        result[id] = _userCache[id]!;
      } else {
        idsToFetch.add(id);
      }
    }

    // If all are cached, return early
    if (idsToFetch.isEmpty) {
      return result;
    }

    // Fetch all users and filter (or could be optimized with batch API)
    try {
      final allUsers = await getUsers();
      for (var user in allUsers) {
        if (idsToFetch.contains(user.id)) {
          result[user.id] = user;
        }
      }
    } catch (e) {
      // If batch fetch fails, individual fetches will be attempted by callers
    }

    return result;
  }

  /// Clear cache - call after login or when data changes
  void clearCache() {
    _userCache.clear();
    _cachedUsers = null;
  }

  /// `GET /api/users/me` — optional; used to read nested shift when attendance omits it.
  Future<Map<String, dynamic>?> fetchCurrentUserPayload() async {
    try {
      final response = await _apiClient.get(AppConstants.usersMe);
      final m = _unwrapUserMap(response.data);
      return m.isEmpty ? null : m;
    } catch (_) {
      return null;
    }
  }

  /// `GET /api/users/:id` — may include shift fields for the signed-in user.
  Future<Map<String, dynamic>?> fetchUserPayloadById(String userId) async {
    final id = userId.trim();
    if (id.isEmpty) return null;
    try {
      final response = await _apiClient.get('${AppConstants.users}/$id');
      final m = _unwrapUserMap(response.data);
      return m.isEmpty ? null : m;
    } catch (_) {
      return null;
    }
  }

  /// `PATCH /api/users/me` — Postman: name, phone.
  Future<User> updateMe({required String name, String phone = ''}) async {
    final response = await _apiClient.patch(
      AppConstants.usersMe,
      data: {'name': name, 'phone': phone},
    );
    return User.fromJson(_unwrapUserMap(response.data));
  }

  Future<User> createUser({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? role,
  }) async {
    final response = await _apiClient.post(
      AppConstants.users,
      data: {
        'name': name,
        'email': email,
        'password': password,
        'phone': phone,
        'role': role,
      },
    );
    return User.fromJson(response.data);
  }

  Future<User> updateUser({
    required String id,
    String? name,
    String? email,
    String? phone,
    String? role,
    bool? isActive,
  }) async {
    final response = await _apiClient.put(
      '${AppConstants.users}/$id',
      data: {
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'isActive': isActive,
      },
    );
    return User.fromJson(response.data);
  }

  Future<void> setUserPassword({
    required String id,
    required String newPassword,
  }) async {
    await _apiClient.put(
      '${AppConstants.users}/$id/password',
      data: {'newPassword': newPassword},
    );
  }

  /// Deactivate current user account (soft delete)
  Future<void> deactivateAccount() async {
    await _apiClient.patch(
      AppConstants.usersMeDeactivate,
      data: {'isActive': false},
    );
    clearCache();
  }
}

Map<String, dynamic> _unwrapUserMap(dynamic raw) {
  if (raw is! Map) return {};
  final m = Map<String, dynamic>.from(raw);
  final inner = m['data'] ?? m['user'];
  if (inner is Map) return Map<String, dynamic>.from(inner);
  return m;
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return UserRepository(apiClient: apiClient);
});
