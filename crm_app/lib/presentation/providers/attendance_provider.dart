import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/location_service.dart';
import '../../data/models/attendance_model.dart';
import '../../data/repositories/attendance_repository.dart';
import '../providers/auth_provider.dart';
import 'dart:async' show Timer;

class AttendanceState {
  final TodayAttendance? todayAttendance;
  final List<AttendanceRecord> records;
  final bool isLoading;
  final String? error;
  final String period; // 'today', 'week', 'month', etc.

  /// Shown when API omits [TodayAttendance.locationIn] after check-in.
  final String? localCheckInLocation;

  /// Shown when API omits [TodayAttendance.locationOut] after check-out.
  final String? localCheckOutLocation;

  const AttendanceState({
    this.todayAttendance,
    this.records = const [],
    this.isLoading = false,
    this.error,
    this.period = 'month',
    this.localCheckInLocation,
    this.localCheckOutLocation,
  });

  AttendanceState copyWith({
    TodayAttendance? todayAttendance,
    List<AttendanceRecord>? records,
    bool? isLoading,
    String? error,
    String? period,
    String? localCheckInLocation,
    String? localCheckOutLocation,
  }) {
    return AttendanceState(
      todayAttendance: todayAttendance ?? this.todayAttendance,
      records: records ?? this.records,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      period: period ?? this.period,
      localCheckInLocation:
          localCheckInLocation ?? this.localCheckInLocation,
      localCheckOutLocation:
          localCheckOutLocation ?? this.localCheckOutLocation,
    );
  }
}

class AttendanceNotifier extends StateNotifier<AttendanceState> {
  final AttendanceRepository _repository;
  final Ref ref;
  Timer? _refreshTimer;

  AttendanceNotifier(this._repository, this.ref)
    : super(const AttendanceState()) {
    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      loadToday();
    });
    // Initial load
    loadToday();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Load today's attendance status with validation
  Future<void> loadToday() async {
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) {
      state = state.copyWith(isLoading: false, error: 'User not authenticated');
      return;
    }
    state = state.copyWith(isLoading: true, error: null);
    try {
      final today = await _repository.getTodayAttendance(currentUserId);
      // Validate: use safeStatus and log if suspicious
      print(
        '📅 Attendance loaded: ${today.safeStatus} for date ${today.date} (isToday: ${today.isToday})',
      );
      if (!today.isToday) {
        print('⚠️  Warning: Attendance date ${today.date} != today');
      }

      final prevDate = state.todayAttendance?.date ?? '';
      final newDate = today.date;
      final dateChanged =
          prevDate.isNotEmpty && newDate.isNotEmpty && prevDate != newDate;

      final serverIn = today.locationIn?.trim() ?? '';
      final serverOut = today.locationOut?.trim() ?? '';

      String? mergedLocalIn;
      String? mergedLocalOut;
      if (dateChanged) {
        mergedLocalIn = null;
        mergedLocalOut = null;
      } else {
        mergedLocalIn = serverIn.isEmpty
            ? state.localCheckInLocation
            : (LocationService.looksLikeCoordinatesString(serverIn)
                  ? state.localCheckInLocation
                  : null);
        mergedLocalOut = serverOut.isEmpty
            ? state.localCheckOutLocation
            : (LocationService.looksLikeCoordinatesString(serverOut)
                  ? state.localCheckOutLocation
                  : null);
      }

      state = AttendanceState(
        todayAttendance: today,
        records: state.records,
        isLoading: false,
        error: null,
        period: state.period,
        localCheckInLocation: mergedLocalIn,
        localCheckOutLocation: mergedLocalOut,
      );
    } catch (e) {
      print('❌ Attendance load error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Manual refresh trigger
  Future<void> refreshNow() async {
    await loadToday();
  }

  /// Load attendance records for period
  Future<void> loadRecords({String period = 'month'}) async {
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) {
      state = state.copyWith(isLoading: false, error: 'User not authenticated');
      return;
    }
    state = state.copyWith(isLoading: true, error: null);
    try {
      final records = await _repository.getRecords(
        currentUserId,
        period: period,
      );
      state = state.copyWith(
        records: records,
        period: period,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// [coordinatesPayload] is sent to the API (e.g. `lat, lng`).
  /// [placeLabel] is shown on the dashboard when the API omits a human address.
  Future<void> checkIn(String coordinatesPayload, String placeLabel) async {
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) {
      state = state.copyWith(error: 'User not authenticated');
      return;
    }
    try {
      print(
        '🟢 Check-in API call: userId=$currentUserId location=$coordinatesPayload',
      );
      await _repository.checkIn(currentUserId, coordinatesPayload);
      final label = placeLabel.trim();
      state = state.copyWith(
        localCheckInLocation: label.isNotEmpty ? label : null,
      );
      print('🔄 Reloading after check-in...');
      // Multiple refreshes to ensure backend sync
      await Future.delayed(const Duration(seconds: 1));
      await loadToday();
      await Future.delayed(const Duration(seconds: 1));
      await loadToday();
      state = state.copyWith();
      print('✅ Check-in complete, state: ${state.todayAttendance?.safeStatus}');
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

  /// [coordinatesPayload] is sent to the API (e.g. `lat, lng`).
  /// [placeLabel] is shown on the dashboard when the API omits a human address.
  Future<void> checkOut(String coordinatesPayload, String placeLabel) async {
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) {
      state = state.copyWith(error: 'User not authenticated');
      return;
    }
    try {
      print(
        '🔴 Check-out API call: userId=$currentUserId location=$coordinatesPayload',
      );
      await _repository.checkOut(currentUserId, coordinatesPayload);
      final label = placeLabel.trim();
      state = state.copyWith(
        localCheckOutLocation: label.isNotEmpty ? label : null,
      );
      print('🔄 Reloading after check-out...');
      // Multiple refreshes to ensure backend sync
      await Future.delayed(const Duration(seconds: 1));
      await loadToday();
      await Future.delayed(const Duration(seconds: 1));
      await loadToday();
      state = state.copyWith();
      print(
        '✅ Check-out complete, state: ${state.todayAttendance?.safeStatus}',
      );
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
      return AttendanceNotifier(repository, ref);
    });
