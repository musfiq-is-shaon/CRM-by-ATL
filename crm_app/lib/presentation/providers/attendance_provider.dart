import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/location_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/utils/attendance_week_utils.dart';
import '../../data/models/attendance_model.dart';
import '../../data/repositories/attendance_repository.dart';
import '../providers/auth_provider.dart';
import 'leave_provider.dart';

/// Sentinel so [AttendanceState.copyWith] can distinguish "omit" from explicit null.
enum _LocalField { unset }

/// Matches [attendance_reminder_controller._alreadyCheckedInToday] — any successful check-in
/// (including before shift start) should clear shift nags.
bool _todayAttendanceIndicatesCheckedIn(TodayAttendance? t) {
  if (t == null) return false;
  if (t.checkInTime != null) return true;
  final s = t.safeStatus.toLowerCase().trim();
  return s == 'checked_in' || s == 'completed' || s == 'checked_out';
}

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
      ref.invalidate(myLeavesForAttendanceProvider);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Attendance load error: $e');
      }
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Clears in-memory attendance when the session ends so the next user never sees stale rows
  /// and reminder scheduling does not churn on old [todayAttendance] keys.
  void resetForLogout() {
    _lastLoadedUserId = null;
    state = const AttendanceState();
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
      List<AttendanceRecord> records;
      if (period == 'week') {
        final range = sundayWeekRangeContaining(DateTime.now());
        try {
          records = await _repository.getRecords(
            dateFrom: range.dateFrom,
            dateTo: range.dateTo,
          );
        } catch (_) {
          records = await _repository.getRecords(period: 'week');
        }
        records = filterAttendanceRecordsToYmdRange(
          records,
          range.dateFrom,
          range.dateTo,
        );
      } else {
        records = await _repository.getRecords(period: period);
      }
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
      if (kDebugMode) {
        debugPrint(
          '🟢 Check-in API call: userId=$currentUserId location=$coordinatesPayload',
        );
      }
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
        if (kDebugMode) {
          debugPrint('⚠️ Immediate merge after check-in: $e\n$st');
        }
      }
      TodayAttendance? postRow;
      try {
        postRow = TodayAttendance.fromJson(checkInBody);
      } catch (_) {
        postRow = null;
      }
      state = state.copyWith(
        localCheckInLocation: label.isNotEmpty ? label : null,
        todayAttendance: quick ?? state.todayAttendance,
      );
      // [mergeLateHintsFromCheckIn] returns early when not late — merged [quick] may omit
      // [checkInTime] even though POST succeeded; also trust raw POST for cancel.
      if (_todayAttendanceIndicatesCheckedIn(quick) ||
          _todayAttendanceIndicatesCheckedIn(postRow)) {
        unawaited(NotificationService().cancelAttendanceCheckInReminders());
      }

      if (kDebugMode) {
        debugPrint('🔄 Scheduling GET /today after check-in (non-blocking)...');
      }
      // Next frame: let late-reconciliation dialog open first; avoid racing [loadToday].
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_refreshTodayAfterCheckIn(checkInBody, idHint));
      });
      if (kDebugMode) {
        debugPrint(
          '✅ Check-in POST applied, late=${state.todayAttendance?.isLate} '
          'mins=${state.todayAttendance?.lateMinutes} status=${state.todayAttendance?.status}',
        );
      }
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
      if (kDebugMode) {
        debugPrint(
          '🔴 Check-out API call: userId=$currentUserId location=$coordinatesPayload',
        );
      }
      final checkOutBody = await _repository.checkOut(coordinatesPayload);
      final label = placeLabel.trim();
      final outIdHint = extractAttendanceRowIdFromApiResponse(checkOutBody);

      TodayAttendance? quick;
      try {
        final prev = state.todayAttendance;
        final base = prev ?? TodayAttendance.fromJson(checkOutBody);
        var merged = base.mergeHintsFromCheckOut(checkOutBody);
        if (merged.checkOutTime != null || merged.isAttendanceFlowCompleted) {
          if (outIdHint != null &&
              outIdHint.isNotEmpty &&
              (merged.id == null || merged.id!.trim().isEmpty)) {
            merged = merged.withAttendanceRowId(outIdHint);
          }
          quick = merged;
        }
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('⚠️ Immediate merge after check-out: $e\n$st');
        }
      }

      state = state.copyWith(
        localCheckOutLocation: label.isNotEmpty ? label : null,
        todayAttendance: quick ?? state.todayAttendance,
      );

      final done = state.todayAttendance?.isAttendanceFlowCompleted ?? false;
      if (done) {
        unawaited(NotificationService().cancelAttendanceCheckInReminders());
      }

      if (kDebugMode) {
        debugPrint('🔄 Reloading after check-out (single refresh)...');
      }
      // Brief delay so GET /today can converge; one load beats two 1s waits + double fetch.
      await Future.delayed(const Duration(milliseconds: 450));
      await loadToday(showLoadingIndicator: false);

      var tOut = state.todayAttendance;
      if (outIdHint != null &&
          outIdHint.isNotEmpty &&
          tOut != null &&
          (tOut.id == null || tOut.id!.trim().isEmpty)) {
        tOut = tOut.withAttendanceRowId(outIdHint);
      }
      // Stale GET: restore checkout fields from POST when the server row still lags.
      if (tOut != null) {
        final recovered = tOut.mergeHintsFromCheckOut(checkOutBody);
        if (recovered.checkOutTime != null && tOut.checkOutTime == null) {
          tOut = recovered;
        } else if (recovered.isAttendanceFlowCompleted &&
            !tOut.isAttendanceFlowCompleted) {
          tOut = recovered;
        }
        state = state.copyWith(todayAttendance: tOut);
      }
      if (kDebugMode) {
        debugPrint(
          '✅ Check-out complete, state: ${state.todayAttendance?.safeStatus}',
        );
      }
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
      if (kDebugMode) {
        debugPrint(
          '✅ GET /today after check-in: late=${state.todayAttendance?.isLate} '
          'mins=${state.todayAttendance?.lateMinutes}',
        );
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('⚠️ Refresh after check-in: $e\n$st');
      }
    }
  }
}

final attendanceProvider =
    StateNotifierProvider<AttendanceNotifier, AttendanceState>((ref) {
      final repository = ref.watch(attendanceRepositoryProvider);
      return AttendanceNotifier(repository, ref);
    });

/// Aggregated status counts for the Attendance hub header (current Sun–Sat week).
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
  final range = sundayWeekRangeContaining(DateTime.now());
  List<AttendanceRecord> rows;
  try {
    rows = await repo.getRecords(
      dateFrom: range.dateFrom,
      dateTo: range.dateTo,
    );
  } catch (_) {
    rows = await repo.getRecords(period: 'week');
  }
  rows = filterAttendanceRecordsToYmdRange(
    rows,
    range.dateFrom,
    range.dateTo,
  );
  return AttendanceWeekRollup.fromRecords(rows);
});
