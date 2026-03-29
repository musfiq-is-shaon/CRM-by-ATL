import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../models/attendance_model.dart';

class AttendanceRepository {
  final ApiClient _apiClient;

  AttendanceRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Get today's attendance status for current user
  Future<TodayAttendance> getTodayAttendance() async {
    final response = await _apiClient.get(AppConstants.attendanceToday);
    return TodayAttendance.fromJson(response.data);
  }

  /// Check-in for today
  Future<void> checkIn(String location) async {
    await _apiClient.post(
      AppConstants.attendanceCheckIn,
      data: {'location': location},
    );
  }

  /// Check-out for today
  Future<void> checkOut(String location) async {
    await _apiClient.post(
      AppConstants.attendanceCheckOut,
      data: {'location': location},
    );
  }

  /// Get attendance records for current user
  Future<List<AttendanceRecord>> getRecords({String period = 'month'}) async {
    final response = await _apiClient.get(
      AppConstants.attendanceRecords,
      queryParameters: {'period': period},
    );
    final List<dynamic> data = response.data;
    return data.map((json) => AttendanceRecord.fromJson(json)).toList();
  }
}

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AttendanceRepository(apiClient: apiClient);
});
