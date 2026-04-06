import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../models/shift_model.dart';

class ShiftRepository {
  ShiftRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<List<WorkShift>> getShifts() async {
    final response = await _api.get(AppConstants.shifts);
    return _parseShiftList(response.data).map(WorkShift.fromJson).toList();
  }

  /// Single shift (often works for assigned employees when list-all is admin-only).
  Future<WorkShift?> getShiftById(String shiftId) async {
    final tid = shiftId.trim();
    if (tid.isEmpty) return null;
    try {
      final response = await _api.get(AppConstants.shiftById(tid));
      final map = _unwrapMap(response.data);
      if (map.isEmpty) return null;
      return WorkShift.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<WorkShift> createShift(WorkShift draft) async {
    final response = await _api.post(
      AppConstants.shifts,
      data: draft.toJsonBody(),
    );
    final map = _unwrapMap(response.data);
    return WorkShift.fromJson(map);
  }

  Future<WorkShift> updateShift(String shiftId, WorkShift draft) async {
    final response = await _api.put(
      AppConstants.shiftById(shiftId),
      data: draft.toJsonBody(),
    );
    final map = _unwrapMap(response.data);
    return WorkShift.fromJson(map);
  }

  Future<void> deleteShift(String shiftId) async {
    await _api.delete(AppConstants.shiftById(shiftId));
  }

  /// [shiftId] `null` removes assignment (Postman).
  Future<void> assignShift({
    required String userId,
    String? shiftId,
  }) async {
    await _api.post(
      AppConstants.shiftsAssign,
      data: {
        'userId': userId,
        'shiftId': shiftId,
      },
    );
  }
}

List<Map<String, dynamic>> _parseShiftList(dynamic body) {
  if (body is List) {
    return body
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  if (body is Map) {
    final m = Map<String, dynamic>.from(body);
    final list = m['data'] ?? m['shifts'] ?? m['results'] ?? m['items'];
    if (list is List) {
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
  }
  return [];
}

Map<String, dynamic> _unwrapMap(dynamic body) {
  if (body is List && body.isNotEmpty && body.first is Map) {
    return _unwrapNested(Map<String, dynamic>.from(body.first as Map));
  }
  if (body is! Map) return {};
  return _unwrapNested(Map<String, dynamic>.from(body));
}

/// Flask/jsonify often nests under `data`, `result`, `shift`, … — unwrap repeatedly.
Map<String, dynamic> _unwrapNested(Map<String, dynamic> m) {
  const keys = [
    'data',
    'shift',
    'result',
    'payload',
    'record',
    'item',
    'body',
  ];
  for (var depth = 0; depth < 8; depth++) {
    var progressed = false;
    for (final key in keys) {
      final inner = m[key];
      if (inner is Map) {
        m = Map<String, dynamic>.from(inner);
        progressed = true;
        break;
      }
    }
    if (!progressed) break;
  }
  return m;
}

final shiftRepositoryProvider = Provider<ShiftRepository>((ref) {
  return ShiftRepository(apiClient: ref.watch(apiClientProvider));
});
