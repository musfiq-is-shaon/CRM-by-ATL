import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/location_service.dart';
import '../../core/services/notification_service.dart';
import '../../data/models/attendance_model.dart';
import '../../data/repositories/attendance_repository.dart';
import '../providers/auth_provider.dart';

/// Sentinel so [AttendanceState.copyWith] can distinguish "omit" from explicit null.
enum _LocalField { unset }

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
    Object? localCheckInLocation = _LocalField.unset,
    Object? localCheckOutLocation = _LocalField.unset,
  }) {
    return AttendanceState(
      todayAttendance: todayAttendance ?? this.todayAttendance,
      records: records ?? this.records,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      period: period ?? this.period,
      localCheckInLocation: localCheckInLocation == _LocalField.unset
          ? this.localCheckInLocation
          : localCheckInLocation as String?,
      localCheckOutLocation: localCheckOutLocation == _LocalField.unset
          ? this.localCheckOutLocation
          : localCheckOutLocation as String?,
    );
  }
}

class AttendanceNotifier extends StateNotifier<AttendanceState> {
  final AttendanceRepository _repository;
  final Ref ref;

  /// Last user id we merged local fallbacks for; used to drop stale locals on account switch.
  String? _lastLoadedUserId;

  AttendanceNotifier(this._repository, this.ref) : super(const AttendanceState()) {
    // Do not call [loadToday] here — it races with [userProfileShiftProvider] (which watches
    // [attendanceProvider]) and can trigger Riverpod [CircularDependencyError]. Shell/dashboard
    // / hub pages call [loadToday] explicitly after auth + tab setup.
  }

  /// Load today's attendance status with validation.
  /// [showLoadingIndicator]: when false (e.g. background refresh after check-in), avoids flipping
  /// [isLoading] so the late-reconciliation dialog can open without a loading flash.
  Future<void> loadToday({bool showLoadingIndicator = true}) async {
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) {
      _lastLoadedUserId = null;
      state = const AttendanceState(
        isLoading: false,
        error: 'User not authenticated',
      );
      return;
    }
    if (showLoadingIndicator) {
      state = state.copyWith(isLoading: true, error: null);
    } else {
      state = state.copyWith(error: null);
    }
    try {
      final today = await _repository.getTodayAttendance();

      final prevDate = state.todayAttendance?.date ?? '';
      final newDate = today.date;
      final dateChanged =
          prevDate.isNotEmpty && newDate.isNotEmpty && prevDate != newDate;

      final userChanged = _lastLoadedUserId != null &&
          _lastLoadedUserId != currentUserId;

      final serverIn = today.locationIn?.trim() ?? '';
      final serverOut = today.locationOut?.trim() ?? '';

      String? mergedLocalIn;
      String? mergedLocalOut;
      if (dateChanged || userChanged) {
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

      _lastLoadedUserId = currentUserId;
      // GET /today often omits row `id` even though check-in POST returned it.
      var mergedToday = today;
      final prev = state.todayAttendance;
      final keptId = prev?.id?.trim();
      if (keptId != null &&
          keptId.isNotEmpty &&
          (today.id == null || today.id!.trim().isEmpty) &&
          prev!.userId == today.userId &&
          attendanceDatesSameCalendarDay(prev.date, today.date)) {
        mergedToday = today.withAttendanceRowId(keptId);
      }
      state = AttendanceState(
        todayAttendance: mergedToday,
        records: state.records,
        isLoading: false,
        error: null,
        period: state.period,
        localCheckInLocation: mergedLocalIn,
        localCheckOutLocation: mergedLocalOut,
      );
    } catch (e) {
      debugPrint('❌ Attendance load error: $e');
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
      _lastLoadedUserId = null;
      state = const AttendanceState(
        isLoading: false,
        error: 'User not authenticated',
      );
      return;
    }
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

  /// [coordinatesPayload] is sent to the API (e.g. `lat, lng`).
  /// [placeLabel] is shown on the dashboard when the API omits a human address.
  Future<void> checkIn(String coordinatesPayload, String placeLabel) async {
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) {
      state = state.copyWith(error: 'User not authenticated');
      return;
    }
    try {
      debugPrint(
        '🟢 Check-in API call: userId=$currentUserId location=$coordinatesPayload',
      );
      final checkInBody = await _repository.checkIn(coordinatesPayload);
      final label = placeLabel.trim();
      final idHint = extractAttendanceRowIdFromApiResponse(checkInBody);

      // Merge POST body immediately so the UI (late chip + reconciliation dialog) is not blocked by GET.
      TodayAttendance? quick;
      try {
        final prev = state.todayAttendance;
        final base = prev ?? TodayAttendance.fromJson(checkInBody);
        quick = base.mergeLateHintsFromCheckIn(checkInBody);
        if (idHint != null &&
            idHint.isNotEmpty &&
            (quick.id == null || quick.id!.trim().isEmpty)) {
          quick = quick.withAttendanceRowId(idHint);
        }
      } catch (e, st) {
        debugPrint('⚠️ Immediate merge after check-in: $e\n$st');
      }
      state = state.copyWith(
        localCheckInLocation: label.isNotEmpty ? label : null,
        todayAttendance: quick ?? state.todayAttendance,
      );
      if (quick?.checkInTime != null) {
        unawaited(NotificationService().cancelAttendanceCheckInReminders());
      }

      debugPrint('🔄 Scheduling GET /today after check-in (non-blocking)...');
      // Next frame: let late-reconciliation dialog open first; avoid racing [loadToday].
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_refreshTodayAfterCheckIn(checkInBody, idHint));
      });
      debugPrint(
        '✅ Check-in POST applied, late=${state.todayAttendance?.isLate} '
        'mins=${state.todayAttendance?.lateMinutes} status=${state.todayAttendance?.status}',
      );
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
      debugPrint(
        '🔴 Check-out API call: userId=$currentUserId location=$coordinatesPayload',
      );
      final checkOutBody = await _repository.checkOut(coordinatesPayload);
      final label = placeLabel.trim();
      state = state.copyWith(
        localCheckOutLocation: label.isNotEmpty ? label : null,
      );
      debugPrint('🔄 Reloading after check-out...');
      final outIdHint = extractAttendanceRowIdFromApiResponse(checkOutBody);
      // Multiple refreshes to ensure backend sync
      await Future.delayed(const Duration(seconds: 1));
      await loadToday();
      await Future.delayed(const Duration(seconds: 1));
      await loadToday();
      var tOut = state.todayAttendance;
      if (outIdHint != null &&
          outIdHint.isNotEmpty &&
          tOut != null &&
          (tOut.id == null || tOut.id!.trim().isEmpty)) {
        state = state.copyWith(
          todayAttendance: tOut.withAttendanceRowId(outIdHint),
        );
      }
      state = state.copyWith();
      debugPrint(
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

  /// Re-sync with GET /today and re-apply late hints from the check-in POST body.
  Future<void> _refreshTodayAfterCheckIn(
    dynamic checkInBody,
    String? idHint,
  ) async {
    try {
      await loadToday(showLoadingIndicator: false);
      var t = state.todayAttendance;
      if (t != null) {
        t = t.mergeLateHintsFromCheckIn(checkInBody);
        if (idHint != null &&
            idHint.isNotEmpty &&
            (t.id == null || t.id!.trim().isEmpty)) {
          t = t.withAttendanceRowId(idHint);
        }
        state = state.copyWith(todayAttendance: t);
      }
      debugPrint(
        '✅ GET /today after check-in: late=${state.todayAttendance?.isLate} '
        'mins=${state.todayAttendance?.lateMinutes}',
      );
    } catch (e, st) {
      debugPrint('⚠️ Refresh after check-in: $e\n$st');
    }
  }
}

final attendanceProvider =
    StateNotifierProvider<AttendanceNotifier, AttendanceState>((ref) {
      final repository = ref.watch(attendanceRepositoryProvider);
      return AttendanceNotifier(repository, ref);
    });

/// Aggregated status counts for the Attendance hub header (`GET .../records?period=week`).
///
/// [present] is **all attended days** (on-time + late). [late] is the subset marked late.
/// [total] counts each calendar row once (`present + absent + other`), not `present + late`.
class AttendanceWeekRollup {
  const AttendanceWeekRollup({
    required this.present,
    required this.late,
    required this.absent,
    required this.other,
  });

  final int present;
  final int late;
  final int absent;
  final int other;

  int get total => present + absent + other;

  factory AttendanceWeekRollup.fromRecords(List<AttendanceRecord> rows) {
    var onTime = 0, late = 0, absent = 0, other = 0;
    for (final r in rows) {
      final s = r.status.toLowerCase().trim();
      switch (s) {
        case 'present':
          onTime++;
          break;
        case 'late':
          late++;
          break;
        case 'absent':
          absent++;
          break;
        case 'early_leave':
        case 'half_day':
          other++;
          break;
        default:
          if (r.checkInTime != null && r.checkOutTime != null) {
            onTime++;
          } else {
            other++;
          }
      }
    }
    final attended = onTime + late;
    return AttendanceWeekRollup(
      present: attended,
      late: late,
      absent: absent,
      other: other,
    );
  }
}

final attendanceWeekRollupProvider =
    FutureProvider.autoDispose<AttendanceWeekRollup>((ref) async {
  final repo = ref.read(attendanceRepositoryProvider);
  final rows = await repo.getRecords(period: 'week');
  return AttendanceWeekRollup.fromRecords(rows);
});
