import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  NotificationRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<List<NotificationItem>> getMyNotifications({
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _api.get(
      AppConstants.notifications,
      queryParameters: {'limit': limit, 'offset': offset},
    );
    var rows = _parseList(response.data);
    if (rows.isEmpty) {
      final fallback = await _api.get(AppConstants.notifications);
      rows = _parseList(fallback.data);
    }
    // Debug visibility for notification payload shape at runtime.
    print('=== NOTIFICATIONS API DEBUG ===');
    print('responseType: ${response.data.runtimeType}');
    print('itemsParsed: ${rows.length}');
    if (rows.isNotEmpty) {
      print('firstItemKeys: ${rows.first.keys.toList()}');
    }
    print('===============================');
    return rows.map(NotificationItem.fromJson).toList();
  }

  Future<void> markAsRead(String notificationId) async {
    await _api.patch(AppConstants.notificationRead(notificationId));
  }

  Future<void> markAllRead() async {
    await _api.patch(AppConstants.notificationsReadAll);
  }

  Future<void> deleteNotification(String notificationId) async {
    await _api.delete(AppConstants.notificationById(notificationId));
  }
}

List<Map<String, dynamic>> _parseList(dynamic body) {
  final direct = _extractList(body);
  if (direct.isNotEmpty) return direct;
  return [];
}

List<Map<String, dynamic>> _extractList(dynamic node) {
  if (node is List) {
    return node
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  if (node is Map) {
    final m = Map<String, dynamic>.from(node);
    for (final key in const [
      'data',
      'notifications',
      'items',
      'results',
      'rows',
      'docs',
      'list',
      'payload',
    ]) {
      final got = _extractList(m[key]);
      if (got.isNotEmpty) return got;
    }
    for (final v in m.values) {
      final got = _extractList(v);
      if (got.isNotEmpty) return got;
    }
  }
  return const [];
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(apiClient: ref.watch(apiClientProvider));
});
