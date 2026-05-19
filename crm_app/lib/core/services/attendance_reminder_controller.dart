import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderListenable, Ref;

import '../json_parse.dart';
import '../network/storage_service.dart';
import '../../data/models/attendance_model.dart';
import '../../data/models/leave_model.dart';
import '../../data/models/shift_model.dart';
import '../../data/repositories/leave_repository.dart';
import '../../presentation/providers/attendance_provider.dart';
import '../../presentation/providers/auth_provider.dart'
    show currentUserIdProvider;
import '../../presentation/providers/user_profile_shift_provider.dart';
import 'notification_service.dart';

/// Postman: `weekendDays` 0=Mon … 6=Sun.
int _weekdayMon0FromDate(DateTime d) {
  final w = d.weekday;
  return w == DateTime.sunday ? 6 : w - 1;
}

/// Builds [NotificationService.attendanceReminderDaysAhead] shift windows from the same template times.
List<AttendanceShiftWindow> _buildShiftWindowsForComingDays({
  required WorkShift? shift,
  required TodayAttendance today,
  required String startRaw,
  required String endRaw,
}) {
  final out = <AttendanceShiftWindow>[];
  final todayDay = _calendarDayFromAttendanceDate(today.date);

  for (var offset = 0;
      offset < NotificationService.effectiveAttendanceDaysAhead;
      offset++) {
    final day = todayDay.add(Duration(days: offset));
    final cal = DateTime(day.year, day.month, day.day);
    if (shift != null && shift.weekendDays.isNotEmpty) {
      if (shift.weekendDays.contains(_weekdayMon0FromDate(cal))) {
        continue;
      }
    }

    final startDt = attendanceDateAtShiftClock(cal, startRaw);
    if (startDt == null) continue;

    var windowEnd = startDt.add(const Duration(hours: 6));
    if (endRaw.isNotEmpty) {
      final endDt = attendanceDateAtShiftClock(cal, endRaw);
      if (endDt != null) {
        var e = endDt;
        if (!e.isAfter(startDt)) {
          e = e.add(const Duration(days: 1));
        }
        if (e.isBefore(windowEnd)) {
          windowEnd = e;
        }
      }
    }

    out.add((anchorLocal: startDt, windowEndLocal: windowEnd));
  }
  return out;
}

/// Drops shift windows on calendar days where the user has approved leave.
List<AttendanceShiftWindow> _shiftWindowsExcludingApprovedLeaveDays(
  List<AttendanceShiftWindow> windows,
  List<LeaveEntry> leaves,
) {
  return windows.where((w) {
    final d = DateTime(w.anchorLocal.year, w.anchorLocal.month, w.anchorLocal.day);
    return approvedLeaveCoveringCalendarDay(leaves, d) == null;
  }).toList();
}

/// Works with both [Ref.read] and [WidgetRef.read].
typedef AttendanceReminderRead = T Function<T>(ProviderListenable<T> provider);

Timer? _queueDebounce;
bool _scheduleRunning = false;
bool _scheduleQueued = false;
AttendanceReminderRead? _queuedRead;

const _queueDebounceDuration = Duration(milliseconds: 450);

/// Debounced entry for Riverpod listeners — avoids rescheduling local notifications
/// on every [AttendanceState] / async shift tick (reduces UI jank).
void queueScheduleAttendanceReminders(
  AttendanceReminderRead read, {
  Duration debounce = _queueDebounceDuration,
}) {
  _queuedRead = read;
  _queueDebounce?.cancel();
  _queueDebounce = Timer(debounce, () {
    _queueDebounce = null;
    unawaited(_runScheduleWithCoalesce());
  });
}

Future<void> _runScheduleWithCoalesce() async {
  if (_queuedRead == null) return;
  if (_scheduleRunning) {
    _scheduleQueued = true;
    return;
  }
  _scheduleRunning = true;
  try {
    do {
      _scheduleQueued = false;
      await scheduleAttendanceReminders(_queuedRead!);
    } while (_scheduleQueued);
  } finally {
    _scheduleRunning = false;
  }
}

/// True if today’s row already has a check-in (including **before shift start** — no nags needed).
bool _alreadyCheckedInToday(TodayAttendance t) {
  return t.checkInTime != null ||
      t.safeStatus == 'checked_in' ||
      t.safeStatus == 'completed' ||
      t.safeStatus == 'checked_out';
}

DateTime _calendarDayFromAttendanceDate(String raw) {
  final p = DateTime.tryParse(raw);
  if (p != null) {
    return DateTime(p.year, p.month, p.day);
  }
  final parts = raw.split('-');
  if (parts.length == 3) {
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y != null && m != null && d != null) {
      return DateTime(y, m, d);
    }
  }
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Schedules or clears local “check in” reminders from [attendance] + [userProfileShiftProvider].
///
/// Pass `ref.read` from a Riverpod [Ref] or `WidgetRef`.
///
/// Lives under `core/services` but imports presentation providers to avoid a Dart import cycle
/// (`attendance_provider` ↔ `user_profile_shift_provider`).
Future<void> scheduleAttendanceReminders(AttendanceReminderRead read) async {
  try {
    // No user → nothing to schedule. Skip storage I/O; [CRMApp] cancels reminders on logout.
    final uid = read(currentUserIdProvider);
    if (uid == null || uid.trim().isEmpty) {
      return;
    }

    final json = await StorageService().getNotificationSettings();
    final enabled = parseOptionalBool(json?['enabled']) ?? false;
    if (!enabled) {
      await NotificationService().cancelAttendanceCheckInReminders();
      return;
    }

    // Resolve shift **before** requiring GET /today. If we only scheduled after `/today`
    // loaded, killing the app early left **zero** OS alarms — reminders appeared only after
    // reopening (when this ran again with `today` set).
    WorkShift? shift;
    try {
      shift = await read(userProfileShiftProvider.future).timeout(
        const Duration(seconds: 20),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Attendance reminders: shift future failed: $e');
      }
      shift = null;
    }

    var today = read(attendanceProvider).todayAttendance;
    var usedSchedulingFallback = false;

    if (today == null) {
      final startFromShift = (shift?.startTime ?? '').trim();
      if (startFromShift.isEmpty) {
        if (kDebugMode) {
          debugPrint(
            'Attendance reminders: GET /today not loaded yet and no shift start — '
            'cannot schedule OS alarms until data is available.',
          );
        }
        return;
      }
      final endTrim = (shift?.endTime ?? '').trim();
      final nameTrim = (shift?.name ?? '').trim();
      final sid = (shift?.id ?? '').trim();
      today = TodayAttendance.schedulingFallback(
        userId: uid,
        shiftStartTime: startFromShift,
        shiftEndTime: endTrim.isEmpty ? null : endTrim,
        shiftName: nameTrim.isEmpty ? null : nameTrim,
        assignedShiftId: sid.isEmpty ? null : sid,
      );
      usedSchedulingFallback = true;
      if (kDebugMode) {
        debugPrint(
          'Attendance reminders: using shift-only fallback until GET /today loads.',
        );
      }
    } else {
      if (!today.isToday) {
        await NotificationService().cancelAttendanceCheckInReminders();
        return;
      }

      if (today.hasNoShift) {
        await NotificationService().cancelAttendanceCheckInReminders();
        return;
      }

      if (_alreadyCheckedInToday(today)) {
        await NotificationService().cancelAttendanceCheckInReminders();
        return;
      }
    }

    // Prefer real `/today` if it landed while we were resolving shift.
    final liveToday = read(attendanceProvider).todayAttendance;
    if (liveToday != null) {
      today = liveToday;
      usedSchedulingFallback = false;
      if (!today.isToday) {
        await NotificationService().cancelAttendanceCheckInReminders();
        return;
      }
      if (today.hasNoShift) {
        await NotificationService().cancelAttendanceCheckInReminders();
        return;
      }
      if (_alreadyCheckedInToday(today)) {
        await NotificationService().cancelAttendanceCheckInReminders();
        return;
      }
    }

    // User may have checked in while shift was loading.
    final todayNow = read(attendanceProvider).todayAttendance;
    if (todayNow != null && _alreadyCheckedInToday(todayNow)) {
      await NotificationService().cancelAttendanceCheckInReminders();
      return;
    }
    final t = todayNow ?? today;

    final startRaw = (shift?.startTime ?? t.shiftStartTime ?? '').trim();
    // Partial API / timeout on shift — don't cancel existing alarms; next successful run will schedule.
    if (startRaw.isEmpty) {
      if (usedSchedulingFallback) {
        debugPrint(
          'Attendance reminders: fallback had no start time after merge — skipping.',
        );
      }
      return;
    }

    final endRaw = (shift?.endTime ?? t.shiftEndTime ?? '').trim();

    final windows = _buildShiftWindowsForComingDays(
      shift: shift,
      today: t,
      startRaw: startRaw,
      endRaw: endRaw,
    );
    if (windows.isEmpty) {
      await NotificationService().cancelAttendanceCheckInReminders();
      return;
    }

    List<LeaveEntry> leaves = const [];
    try {
      leaves = await read(leaveRepositoryProvider).getMyLeaves().timeout(
            const Duration(seconds: 12),
          );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Attendance reminders: leaves load failed: $e');
      }
    }
    final windowsForReminders =
        _shiftWindowsExcludingApprovedLeaveDays(windows, leaves);
    if (windowsForReminders.isEmpty) {
      await NotificationService().cancelAttendanceCheckInReminders();
      return;
    }

    final label = () {
      final n = shift?.name.trim() ?? '';
      if (n.isNotEmpty) return n;
      return t.shiftName?.trim() ?? '';
    }();

    final lastRead = read(attendanceProvider).todayAttendance;
    if (lastRead != null && _alreadyCheckedInToday(lastRead)) {
      await NotificationService().cancelAttendanceCheckInReminders();
      return;
    }

    await NotificationService().scheduleAttendanceCheckInReminders(
      windows: windowsForReminders,
      shiftLabel: label,
    );
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('scheduleAttendanceReminders: $e\n$st');
    }
  }
}

/// Notifier / isolate-friendly entry when you have a [Ref].
Future<void> scheduleAttendanceRemindersFromRef(Ref ref) =>
    scheduleAttendanceReminders(ref.read);

/// Debounced variant for providers that must not storm the notification plugin.
void queueScheduleAttendanceRemindersFromRef(
  Ref ref, {
  Duration debounce = _queueDebounceDuration,
}) =>
    queueScheduleAttendanceReminders(ref.read, debounce: debounce);
