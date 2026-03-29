import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/attendance_model.dart';
import '../../data/repositories/attendance_repository.dart';

class AttendanceState {
  final TodayAttendance? todayAttendance;
  final List<AttendanceRecord> records;
  final bool isLoading;
  final String? error;
  final String period; // 'today', 'week', 'month', etc.

  const AttendanceState({
    this.todayAttendance,
    this.records = const [],
    this.isLoading = false,
    this.error,
    this.period = 'month',
  });

  AttendanceState copyWith({
    TodayAttendance? todayAttendance,
    List<AttendanceRecord>? records,
    bool? isLoading,
    String? error,
    String? period,
  }) {
    return AttendanceState(
      todayAttendance: todayAttendance ?? this.todayAttendance,
      records: records ?? this.records,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      period: period ?? this.period,
    );
  }
}

class AttendanceNotifier extends StateNotifier<AttendanceState> {
  final AttendanceRepository _repository;

  AttendanceNotifier(this._repository) : super(const AttendanceState());

  /// Load today's attendance status
  Future<void> loadToday() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final today = await _repository.getTodayAttendance();
      state = state.copyWith(todayAttendance: today, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Load attendance records for period
  Future<void> loadRecords({String period = 'month'}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final records = await _repository.getRecords(period: period);
      state = state.copyWith(
        records: records,
        period: period,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Perform check-in
  Future<void> checkIn(String location) async {
    try {
      await _repository.checkIn(location);
      // Refresh today status
      await loadToday();
      // Force UI refresh
      Future.delayed(const Duration(milliseconds: 500), () {
        state = state.copyWith();
      });
    } catch (e) {
      String errorMsg = 'Something went wrong. Please try again.';
      if (e.toString().contains('Already checked in')) {
        errorMsg = 'Already checked in today';
      } else if (e.toString().contains('Already checked out')) {
        errorMsg = 'Already checked out today';
      }
      state = state.copyWith(error: errorMsg);
      // Auto clear error after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        state = state.copyWith(error: null);
      });
    }
  }

  /// Perform check-out
  Future<void> checkOut(String location) async {
    try {
      await _repository.checkOut(location);
      // Refresh today status
      await loadToday();
      // Force UI refresh
      Future.delayed(const Duration(milliseconds: 500), () {
        state = state.copyWith();
      });
    } catch (e) {
      String errorMsg = 'Something went wrong. Please try again.';
      if (e.toString().contains('Already checked out')) {
        errorMsg = 'Already checked out today';
      }
      state = state.copyWith(error: errorMsg);
      // Auto clear error after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        state = state.copyWith(error: null);
      });
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final attendanceProvider =
    StateNotifierProvider<AttendanceNotifier, AttendanceState>((ref) {
      final repository = ref.watch(attendanceRepositoryProvider);
      return AttendanceNotifier(repository);
    });
