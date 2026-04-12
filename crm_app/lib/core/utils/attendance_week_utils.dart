import '../../data/models/attendance_model.dart';

/// Local calendar date only (no time / UTC drift for “today”).
DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// `yyyy-MM-dd` using local calendar date.
String attendanceDateYmd(DateTime d) {
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Sunday 00:00 (local) at the start of the Sun–Sat week containing [reference].
///
/// Dart [DateTime.weekday]: Mon = 1 … Sun = 7.
DateTime startOfSundayWeekContaining(DateTime reference) {
  final d = _dateOnly(reference);
  final wd = d.weekday;
  final daysBack = wd == DateTime.sunday ? 0 : wd;
  return d.subtract(Duration(days: daysBack));
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
