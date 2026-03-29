import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../models/attendance_model.dart';

class AttendanceRepository {
  final ApiClient _apiClient;

  AttendanceRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Get today's attendance status for user
  Future<TodayAttendance> getTodayAttendance(String userId) async {
    final response = await _apiClient.get(
      AppConstants.attendanceToday,
      queryParameters: {'userId': userId},
    );
    return TodayAttendance.fromJson(response.data);
  }

  /// Check-in for today
  Future<void> checkIn(String userId, String location) async {
    await _apiClient.post(
      AppConstants.attendanceCheckIn,
      data: {'userId': userId, 'location': location},
    );
  }

  /// Check-out for today
  Future<void> checkOut(String userId, String location) async {
    await _apiClient.post(
      AppConstants.attendanceCheckOut,
      data: {'userId': userId, 'location': location},
    );
  }

  /// Get attendance records for user
  Future<List<AttendanceRecord>> getRecords(
    String userId, {
    String period = 'month',
  }) async {
    final response = await _apiClient.get(
      AppConstants.attendanceRecords,
      queryParameters: {'userId': userId, 'period': period},
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
