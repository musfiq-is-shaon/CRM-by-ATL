import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../models/task_model.dart';

class TaskRepository {
  final ApiClient _apiClient;

  TaskRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  static dynamic _unwrap(dynamic raw) {
    if (raw is Map && raw['data'] != null) return raw['data'];
    return raw;
  }

  /// Task log GET responses sometimes wrap the array (`logs`, `items`, nested `data`).
  static List<dynamic> _taskLogsList(dynamic raw) {
    final u = _unwrap(raw);
    if (u is List) return u;
    if (u is Map) {
      for (final key in ['logs', 'items', 'results', 'records', 'rows']) {
        final v = u[key];
        if (v is List) return v;
      }
      final inner = u['data'];
      if (inner is List) return inner;
      if (inner is Map) {
        for (final key in ['logs', 'items', 'results']) {
          final v = inner[key];
          if (v is List) return v;
        }
      }
    }
    return [];
  }

  Future<List<Task>> getTasks({
    String? status,
    String? companyId,
    String? assignToUserId,
    String? assignByUserId,
    String? search,
  }) async {
    final queryParams = <String, dynamic>{};
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (companyId != null && companyId.isNotEmpty) {
      queryParams['companyId'] = companyId;
    }
    if (assignToUserId != null && assignToUserId.isNotEmpty) {
      queryParams['assignToUserId'] = assignToUserId;
    }
    if (assignByUserId != null && assignByUserId.isNotEmpty) {
      queryParams['assignByUserId'] = assignByUserId;
    }
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final response = await _apiClient.get(
      AppConstants.tasks,
      queryParameters: queryParams,
    );
    final List<dynamic> data = response.data;
    return data.map((json) => Task.fromJson(json)).toList();
  }

  Future<Task> getTaskById(String id) async {
    final response = await _apiClient.get('${AppConstants.tasks}/$id');
    return Task.fromJson(response.data);
  }

  Future<Task> createTask({
    required String title,
    String? note,
    required String companyId,
    required DateTime dueDatetime,
    String? assignByUserId,
    String? assignToUserId,
    String? actorUserId,
  }) async {
    final data = {
      'title': title,
      'companyId': companyId,
      'dueDatetime': dueDatetime.toIso8601String(),
      'note': note,
      'assignByUserId': assignByUserId,
      'assignToUserId': assignToUserId,
      'actorUserId': actorUserId,
    };

    if (kDebugMode) {
      debugPrint('=== API REQUEST: CREATE TASK ===');
      debugPrint('Data: $data');
      debugPrint('=================================');
    }

    final response = await _apiClient.post(AppConstants.tasks, data: data);
    return Task.fromJson(response.data);
  }

  Future<Task> updateTask({
    required String id,
    String? title,
    String? note,
    String? companyId,
    DateTime? dueDatetime,
    String? assignByUserId,
    String? assignToUserId,
    String? actorUserId,
  }) async {
    final response = await _apiClient.put(
      '${AppConstants.tasks}/$id',
      data: {
        'title': title,
        'note': note,
        'companyId': companyId,
        if (dueDatetime != null) 'dueDatetime': dueDatetime.toIso8601String(),
        'assignByUserId': assignByUserId,
        'assignToUserId': assignToUserId,
        'actorUserId': actorUserId,
      },
    );
    return Task.fromJson(response.data);
  }

  Future<Task> changeTaskStatus({
    required String id,
    required String status,
    String? note,
    String? actorUserId,
  }) async {
    final data = <String, dynamic>{'status': status};
    if (note != null) data['note'] = note;
    if (actorUserId != null && actorUserId.isNotEmpty) {
      data['actorUserId'] = actorUserId;
    }
    final response = await _apiClient.patch(
      '${AppConstants.tasks}/$id/status',
      data: data,
    );
    return Task.fromJson(response.data);
  }

  Future<List<TaskLog>> getTaskLogs(String taskId) async {
    final response = await _apiClient.get('${AppConstants.tasks}/$taskId/logs');
    final data = _taskLogsList(response.data);
    var order = 0;
    return data
        .whereType<Map>()
        .map((raw) {
          final m = Map<String, dynamic>.from(raw);
          m['_sourceIndex'] = order++;
          return TaskLog.fromJson(m);
        })
        .toList();
  }

  Future<void> deleteTask(String id) async {
    await _apiClient.delete('${AppConstants.tasks}/$id');
  }
}

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TaskRepository(apiClient: apiClient);
});
