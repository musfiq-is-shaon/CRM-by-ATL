import '../../data/models/attendance_model.dart';

/// Local calendar date at midnight. Uses [DateTime.toLocal] first so UTC instants align
/// with the device’s weekday (fixes Sun–Sat “this week” vs ISO Mon–Sun when dates were UTC).
DateTime _dateOnlyLocal(DateTime d) {
  final l = d.toLocal();
  return DateTime(l.year, l.month, l.day);
}

/// `yyyy-MM-dd` for the **local** calendar day (see [_dateOnlyLocal]).
String attendanceDateYmd(DateTime d) {
  final l = _dateOnlyLocal(d);
  return '${l.year.toString().padLeft(4, '0')}-'
      '${l.month.toString().padLeft(2, '0')}-'
      '${l.day.toString().padLeft(2, '0')}';
}

/// Sunday 00:00 **local** at the start of the Sun–Sat week containing [reference].
///
/// Dart [DateTime.weekday]: Mon = 1 … Sun = 7. This is **not** ISO week (Mon–Sun).
DateTime startOfSundayWeekContaining(DateTime reference) {
  final d = _dateOnlyLocal(reference);
  final wd = d.weekday;
  final daysBackFromSunday = wd == DateTime.sunday ? 0 : wd;
  return d.subtract(Duration(days: daysBackFromSunday));
}

/// Inclusive Saturday (same week as [startSunday]).
DateTime endOfSaturdayWeek(DateTime startSunday) {
  return startSunday.add(const Duration(days: 6));
}

/// Current Sun–Sat week (local), inclusive YYYY-MM-DD strings.
({String dateFrom, String dateTo}) sundayWeekRangeContaining(DateTime reference) {
  final start = startOfSundayWeekContaining(reference);
  final end = endOfSaturdayWeek(start);
  return (dateFrom: attendanceDateYmd(start), dateTo: attendanceDateYmd(end));
}

/// Previous Sun–Sat block (local), inclusive.
({String dateFrom, String dateTo}) previousSundayWeekRange(DateTime reference) {
  final thisStart = startOfSundayWeekContaining(reference);
  final prevStart = thisStart.subtract(const Duration(days: 7));
  final prevEnd = endOfSaturdayWeek(prevStart);
  return (
    dateFrom: attendanceDateYmd(prevStart),
    dateTo: attendanceDateYmd(prevEnd),
  );
}

/// Keep rows whose [AttendanceRecord.date] falls in [dateFrom]…[dateTo] (inclusive).
List<AttendanceRecord> filterAttendanceRecordsToYmdRange(
  List<AttendanceRecord> rows,
  String dateFrom,
  String dateTo,
) {
  final from = dateFrom.trim();
  final to = dateTo.trim();
  if (from.isEmpty || to.isEmpty) return rows;
  return rows.where((r) {
    final d = r.date.trim();
    if (d.length < 10) return false;
    final day = d.length >= 10 ? d.substring(0, 10) : d;
    return day.compareTo(from) >= 0 && day.compareTo(to) <= 0;
  }).toList();
}

/// History lists: newest calendar day first.
List<AttendanceRecord> sortAttendanceRecordsByDateDesc(
  List<AttendanceRecord> rows,
) {
  final copy = [...rows];
  copy.sort((a, b) => b.date.compareTo(a.date));
  return copy;
}

/// Whether a row should affect hub week stat chips (skip weekends, holidays, future days).
bool attendanceRecordCountsTowardRollup(
  AttendanceRecord r, {
  String? todayYmd,
}) {
  if (r.isNonWorkingDay) return false;
  final day = r.date.trim();
  if (day.length < 10) return false;
  final ymd = day.substring(0, 10);
  final today = todayYmd ?? attendanceDateYmd(DateTime.now());
  if (ymd.compareTo(today) > 0) return false;
  return true;
}
