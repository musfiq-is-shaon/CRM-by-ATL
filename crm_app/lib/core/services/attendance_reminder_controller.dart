import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderListenable, Ref;

import '../json_parse.dart';
import '../network/storage_service.dart';
import '../../data/models/attendance_model.dart';
import '../../data/models/shift_model.dart';
import '../../presentation/providers/attendance_provider.dart';
import '../../presentation/providers/auth_provider.dart';
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
      offset < NotificationService.attendanceReminderDaysAhead;
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

/// Works with both [Ref.read] and [WidgetRef.read].
typedef AttendanceReminderRead = T Function<T>(ProviderListenable<T> provider);

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
    final json = await StorageService().getNotificationSettings();
    final enabled = parseOptionalBool(json?['enabled']) ?? true;
    if (!enabled) {
      await NotificationService().cancelAttendanceCheckInReminders();
      return;
    }

    final uid = read(currentUserIdProvider);
    if (uid == null || uid.trim().isEmpty) {
      await NotificationService().cancelAttendanceCheckInReminders();
      return;
    }

    final today = read(attendanceProvider).todayAttendance;
    if (today == null) {
      await NotificationService().cancelAttendanceCheckInReminders();
      return;
    }

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

    WorkShift? shift;
    try {
      shift = await read(userProfileShiftProvider.future);
    } catch (e) {
      debugPrint('Attendance reminders: shift future failed: $e');
    }

    // User may have checked in (even early, before shift) while shift was loading.
    final todayNow = read(attendanceProvider).todayAttendance;
    if (todayNow != null && _alreadyCheckedInToday(todayNow)) {
      await NotificationService().cancelAttendanceCheckInReminders();
      return;
    }
    final t = todayNow ?? today;

    final startRaw = (shift?.startTime ?? t.shiftStartTime ?? '').trim();
    if (startRaw.isEmpty) {
      await NotificationService().cancelAttendanceCheckInReminders();
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
      windows: windows,
      shiftLabel: label,
    );
  } catch (e, st) {
    debugPrint('scheduleAttendanceReminders: $e\n$st');
  }
}

/// Notifier / isolate-friendly entry when you have a [Ref].
Future<void> scheduleAttendanceRemindersFromRef(Ref ref) =>
    scheduleAttendanceReminders(ref.read);
