import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
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
  Future<void> checkIn(String location) async {
    await _apiClient.post(
      AppConstants.attendanceCheckIn,
      data: {'location': location},
    );
  }

  Future<void> checkOut(String location) async {
    await _apiClient.post(
      AppConstants.attendanceCheckOut,
      data: {'location': location},
    );
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
