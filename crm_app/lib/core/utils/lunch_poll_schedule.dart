import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

TimeOfDay lunchEndTimeOfDay(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return const TimeOfDay(hour: 18, minute: 0);
  }
  final t = raw.trim();
  // Normalize 12h strings first — DateFormat.jm() is locale-sensitive and can fail.
  if (t.contains('AM') || t.contains('PM') || t.contains('am') || t.contains('pm')) {
    final api = lunchEndTimeToApi(t);
    final parts = api.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 18,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
  }
  try {
    final parsed = DateFormat.jm().parse(t);
    return TimeOfDay(hour: parsed.hour, minute: parsed.minute);
  } catch (_) {
    final parts = t.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 18,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
  }
}

DateTime? lunchPollEndDateTime(DateTime? pollDate, String? endTime) {
  if (endTime == null || endTime.trim().isEmpty) return null;
  final base = (pollDate ?? DateTime.now()).toLocal();
  final day = DateTime(base.year, base.month, base.day);
  final tod = lunchEndTimeOfDay(endTime);
  return DateTime(day.year, day.month, day.day, tod.hour, tod.minute);
}

bool lunchPollIsPastEndTime({
  required String? endTime,
  required DateTime? pollDate,
  required String status,
}) {
  if (endTime == null || endTime.trim().isEmpty) return false;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  if (status.toLowerCase() == 'active' && pollDate != null) {
    final pollDay = DateTime(pollDate.year, pollDate.month, pollDate.day);
    if (pollDay.isBefore(today)) {
      // Reactivated polls use today's deadline, not the original poll date.
      final todayDeadline = lunchPollEndDateTime(today, endTime);
      if (todayDeadline != null) return now.isAfter(todayDeadline);
      return false;
    }
  }

  final deadline = lunchPollEndDateTime(pollDate, endTime);
  if (deadline == null) return false;
  return now.isAfter(deadline);
}

String lunchEndTimeToApi(String display) {
  final t = display.trim();
  if (t.isEmpty) return t;
  try {
    final parsed = DateFormat.jm().parse(t);
    return '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  } catch (_) {}
  // Manual 12h parse: "6:30 PM" / "6:30PM" / "06:30 am"
  final ampm = RegExp(
    r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])$',
  ).firstMatch(t);
  if (ampm != null) {
    var h = int.tryParse(ampm.group(1)!) ?? 0;
    final m = int.tryParse(ampm.group(2)!) ?? 0;
    final period = ampm.group(3)!.toUpperCase();
    if (period == 'AM') {
      if (h == 12) h = 0;
    } else {
      if (h != 12) h += 12;
    }
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
  final parts = t.split(':');
  if (parts.length >= 2) {
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
  return t;
}

String lunchDefaultEndTimeApi({int minutesFromNow = 60}) {
  final end = DateTime.now().add(Duration(minutes: minutesFromNow));
  return '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
}

bool isPollEndTimeViable(String? endTime, DateTime? pollDate) {
  if (endTime == null || endTime.trim().isEmpty) return false;
  final api = endTime.contains('AM') || endTime.contains('PM')
      ? lunchEndTimeToApi(endTime)
      : endTime.trim();
  return !lunchPollIsPastEndTime(
    endTime: api,
    pollDate: pollDate,
    status: 'active',
  );
}

String? preferPollEndTime({
  required String? prior,
  required String? incoming,
  required DateTime? pollDate,
}) {
  String? norm(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return raw.trim();
  }

  final a = norm(prior);
  final b = norm(incoming);
  if (a == null) return b;
  if (b == null) return a;

  bool viable(String endTime) => !lunchPollIsPastEndTime(
        endTime: endTime,
        pollDate: pollDate,
        status: 'active',
      );

  final aOk = viable(a);
  final bOk = viable(b);
  if (aOk && !bOk) return a;
  if (bOk && !aOk) return b;
  // Prefer incoming/server end time when both (or neither) are viable.
  return b;
}

/// Whether an active poll should appear on My Lunch (includes reactivated older polls).
bool lunchPollShowOnMyLunch({
  required String id,
  required String status,
  required DateTime? date,
  required String? endTime,
  required bool isCancelled,
}) {
  if (id.isEmpty || isCancelled) return false;
  if (status.toLowerCase() != 'active') return false;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  if (date != null) {
    final pollDay = DateTime(date.year, date.month, date.day);
    if (pollDay.isBefore(today)) {
      return !lunchPollIsPastEndTime(
        endTime: endTime,
        pollDate: date,
        status: 'active',
      );
    }
  }
  return true;
}

/// Minutes from now until [endTimeApi] today (minimum 15).
int lunchExtendMinutesUntil(String endTimeApi) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final deadline = lunchPollEndDateTime(today, endTimeApi);
  if (deadline == null) return 60;
  final diff = deadline.difference(now).inMinutes;
  return diff.clamp(15, 24 * 60);
}
