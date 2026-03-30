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
  if (body is Map<String, dynamic>) {
    final inner = body['data'] ?? body['shift'];
    if (inner is Map) return Map<String, dynamic>.from(inner);
    return body;
  }
  if (body is Map) {
    final m = Map<String, dynamic>.from(body);
    final inner = m['data'] ?? m['shift'];
    if (inner is Map) return Map<String, dynamic>.from(inner);
    return m;
  }
  return {};
}

final shiftRepositoryProvider = Provider<ShiftRepository>((ref) {
  return ShiftRepository(apiClient: ref.watch(apiClientProvider));
});
