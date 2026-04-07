import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/network/api_client.dart';
import '../models/shift_model.dart';

class ShiftRepository {
  ShiftRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<List<WorkShift>> getShifts() async {
    final response = await _api.get(AppConstants.shifts);
    return _parseShiftList(response.data).map(WorkShift.fromJson).toList();
  }

  /// Same as [getShifts], then merges `employeeIds` from `GET /shifts/:id` when the list omits rosters.
  Future<List<WorkShift>> getShiftsEnriched() async {
    var list = await getShifts();
    // Avoid N+1 GET /shifts/:id when the list payload already has times (detail often 403 for
    // employees; roster merge is only needed when we lack employeeIds *and* times).
    final need = list
        .where(
          (s) =>
              s.id.trim().isNotEmpty &&
              s.employeeIds.isEmpty &&
              (s.startTime.trim().isEmpty || s.endTime.trim().isEmpty),
        )
        .toList();
    if (need.isEmpty) return list;
    final details = await Future.wait(
      need.map((s) => getShiftById(s.id)),
    );
    final byId = <String, WorkShift>{};
    for (var i = 0; i < need.length; i++) {
      final d = details[i];
      if (d != null && d.id.trim().isNotEmpty) {
        byId[d.id.trim().toLowerCase()] = d;
      }
    }
    return list
        .map(
          (s) => WorkShift.mergeRosterFromDetail(
            s,
            byId[s.id.trim().toLowerCase()],
          ),
        )
        .toList();
  }

  /// Single shift (often works for assigned employees when list-all is admin-only).
  Future<WorkShift?> getShiftById(String shiftId) async {
    final tid = shiftId.trim();
    if (tid.isEmpty) return null;
    try {
      final response = await _api.get(AppConstants.shiftById(tid));
      var map = _unwrapMap(response.data);
      if (map.isEmpty && response.data is Map) {
        final m = Map<String, dynamic>.from(response.data as Map);
        final looksLikeShift = m.containsKey('startTime') ||
            m.containsKey('start_time') ||
            m.containsKey('endTime') ||
            m.containsKey('end_time') ||
            m.containsKey('name') ||
            m.containsKey('employeeIds') ||
            m.containsKey('employee_ids');
        if (looksLikeShift) map = m;
      }
      if (map.isEmpty) {
        if (kDebugMode) {
          debugPrint(
            'getShiftById($tid): empty after unwrap, '
            'topKeys=${response.data is Map ? (response.data as Map).keys.toList() : response.data.runtimeType}',
          );
        }
        return null;
      }
      return WorkShift.fromJson(map);
    } catch (e, st) {
      if (kDebugMode) {
        final sc = e is AppException ? e.statusCode : null;
        debugPrint('getShiftById($tid) status=$sc: $e\n$st');
      }
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
