import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/network/api_client.dart';
import '../models/attendance_model.dart';

class AttendanceRepository {
  final ApiClient _apiClient;

  AttendanceRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Today's attendance for the **current user** (Bearer token). No query params.
  Future<TodayAttendance> getTodayAttendance() async {
    final response = await _apiClient.get(AppConstants.attendanceToday);
    return TodayAttendance.fromJson(response.data);
  }

  /// Body: `{ "location": "<lat>, <lng>" }` only (Postman / Flask API).
  /// Returns response body — may include attendance row `id` for reconciliation.
  Future<dynamic> checkIn(String location) async {
    final response = await _apiClient.post(
      AppConstants.attendanceCheckIn,
      data: {'location': location},
    );
    return response.data;
  }

  Future<dynamic> checkOut(String location) async {
    final response = await _apiClient.post(
      AppConstants.attendanceCheckOut,
      data: {'location': location},
    );
    return response.data;
  }

  /// My records: `GET /api/attendance/records?period=...` (current user).
  Future<List<AttendanceRecord>> getRecords({String period = 'month'}) async {
    final response = await _apiClient.get(
      AppConstants.attendanceRecords,
      queryParameters: {'period': period},
    );
    final rows = _recordsListFromResponse(response.data);
    return rows.map(AttendanceRecord.fromJson).toList();
  }

  /// List reconciliations. Applicants: own rows. Admins: optional filters.
  Future<List<AttendanceReconciliation>> getReconciliations({
    String? status,
    String? userId,
    String? dateFrom,
    String? dateTo,
  }) async {
    final qp = <String, dynamic>{};
    if (status != null && status.isNotEmpty) qp['status'] = status;
    if (userId != null && userId.isNotEmpty) qp['userId'] = userId;
    if (dateFrom != null && dateFrom.isNotEmpty) qp['dateFrom'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) qp['dateTo'] = dateTo;
    final response = await _apiClient.get(
      AppConstants.attendanceReconciliations,
      queryParameters: qp.isEmpty ? null : qp,
    );
    final rows = reconciliationsListFromResponse(response.data);
    return rows.map(AttendanceReconciliation.fromJson).toList();
  }

  Future<void> createReconciliation({
    required String attendanceId,
    required String reason,
  }) async {
    try {
      await _apiClient.post(
        AppConstants.attendanceReconciliations,
        data: {'attendanceId': attendanceId, 'reason': reason},
      );
    } on AppException catch (e) {
      final sc = e.statusCode;
      if (sc == 400 || sc == 422) {
        await _apiClient.post(
          AppConstants.attendanceReconciliations,
          data: {'attendance_id': attendanceId, 'reason': reason},
        );
        return;
      }
      rethrow;
    }
  }

  Future<void> reviewReconciliation({
    required String reconciliationId,
    required String status,
    String? reviewNote,
  }) async {
    final body = <String, dynamic>{'status': status};
    if (reviewNote != null && reviewNote.trim().isNotEmpty) {
      body['reviewNote'] = reviewNote.trim();
    }
    await _apiClient.patch(
      AppConstants.attendanceReconciliationReview(reconciliationId),
      data: body,
    );
  }
}

List<Map<String, dynamic>> _recordsListFromResponse(dynamic body) {
  if (body is List) {
    return body
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  if (body is Map) {
    final m = Map<String, dynamic>.from(body);
    final list = m['data'] ?? m['records'] ?? m['results'] ?? m['items'];
    if (list is List) {
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
  }
  return [];
}

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AttendanceRepository(apiClient: apiClient);
});
