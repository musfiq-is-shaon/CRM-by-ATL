import 'user_model.dart';

/// API sends ISO-8601; UTC (`Z` / offset) must become local for display.
DateTime? _parseAttendanceDateTime(dynamic raw) {
  if (raw == null) return null;
  final parsed = DateTime.tryParse(raw.toString());
  if (parsed == null) return null;
  return parsed.isUtc ? parsed.toLocal() : parsed;
}

class TodayAttendance {
  final String userId;
  final String status; // 'pending', 'checked_in', 'checked_out', 'completed', 'no_shift', ...
  final String date; // '2025-01-20'
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final bool isLate;
  final int? lateMinutes;
  final double? totalHours;
  final String? locationIn;
  final String? locationOut;
  /// From API when shift is required for attendance (see Postman / HR shifts).
  final bool? hasShiftAssigned;
  final bool? isWeekend;
  final bool? isHoliday;
  /// Snapshot from nested `shift` on `/api/attendance/today` when API sends it.
  final String? shiftName;
  final String? shiftStartTime;
  final String? shiftEndTime;
  final int? shiftGraceMinutes;

  TodayAttendance({
    required this.userId,
    required this.status,
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    required this.isLate,
    this.lateMinutes,
    this.totalHours,
    this.locationIn,
    this.locationOut,
    this.hasShiftAssigned,
    this.isWeekend,
    this.isHoliday,
    this.shiftName,
    this.shiftStartTime,
    this.shiftEndTime,
    this.shiftGraceMinutes,
  });

  factory TodayAttendance.fromJson(dynamic raw) {
    final json = _unwrapTodayJson(raw);
    final checkInTime = _parseAttendanceDateTime(
      json['checkInTime'] ?? json['check_in_time'],
    );
    final checkOutTime = _parseAttendanceDateTime(
      json['checkOutTime'] ?? json['check_out_time'],
    );
    String? shiftName;
    String? shiftStart;
    String? shiftEnd;
    int? shiftGrace;
    final shiftObj = json['shift'] ?? json['shiftInfo'] ?? json['shift_info'];
    if (shiftObj is Map) {
      final sm = Map<String, dynamic>.from(shiftObj);
      shiftName = sm['name']?.toString();
      shiftStart =
          (sm['startTime'] ?? sm['start_time'])?.toString();
      shiftEnd = (sm['endTime'] ?? sm['end_time'])?.toString();
      shiftGrace = _optionalInt(sm['gracePeriod'] ?? sm['grace_period']);
    }
    shiftName ??= json['shiftName']?.toString() ?? json['shift_name']?.toString();
    shiftStart ??=
        json['shiftStartTime']?.toString() ?? json['shift_start_time']?.toString();
    shiftEnd ??=
        json['shiftEndTime']?.toString() ?? json['shift_end_time']?.toString();
    shiftGrace ??= _optionalInt(json['shiftGraceMinutes'] ?? json['shift_grace_minutes']);

    return TodayAttendance(
      userId: (json['userId'] ?? json['user_id'] ?? '').toString(),
      status: json['status'] ?? 'pending',
      date: (json['date'] ?? '').toString(),
      checkInTime: checkInTime,
      checkOutTime: checkOutTime,
      isLate: json['isLate'] ?? json['is_late'] ?? false,
      lateMinutes: _optionalInt(json['lateMinutes'] ?? json['late_minutes']),
      totalHours: _optionalDouble(json['totalHours'] ?? json['total_hours']),
      hasShiftAssigned: _optionalBool(
        json['hasShiftAssigned'] ?? json['has_shift_assigned'],
      ),
      isWeekend: _optionalBool(json['isWeekend'] ?? json['is_weekend']),
      isHoliday: _optionalBool(json['isHoliday'] ?? json['is_holiday']),
      shiftName: shiftName,
      shiftStartTime: shiftStart,
      shiftEndTime: shiftEnd,
      shiftGraceMinutes: shiftGrace,
      locationIn: _pickLocationString(
        json,
        const [
          'locationIn',
          'location_in',
          'checkInLocation',
          'check_in_location',
          'inLocation',
          'in_location',
        ],
      ),
      locationOut: _pickLocationString(
        json,
        const [
          'locationOut',
          'location_out',
          'checkOutLocation',
          'check_out_location',
          'outLocation',
          'out_location',
        ],
      ),
    );
  }

  /// API may return `{ "data": { ... } }` or snake_case keys.
  static Map<String, dynamic> _unwrapTodayJson(dynamic raw) {
    if (raw is! Map) return {};
    var m = Map<String, dynamic>.from(raw);
    for (final key in ['data', 'attendance', 'record', 'today', 'result']) {
      final v = m[key];
      if (v is Map) {
        m = Map<String, dynamic>.from(v);
        break;
      }
    }
    return m;
  }

  static String? _pickLocationString(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final v = json[key];
      if (v == null) continue;
      final s = v is String ? v : v.toString();
      final t = s.trim();
      if (t.isNotEmpty) return t;
    }
    return null;
  }

  static bool? _optionalBool(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v;
    final s = v.toString().toLowerCase();
    if (s == 'true') return true;
    if (s == 'false') return false;
    return null;
  }

  static int? _optionalInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString());
  }

  static double? _optionalDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }

  bool get isPending => status == 'pending';
  bool get isCheckedIn => status == 'checked_in';
  bool get isCheckedOut => status == 'checked_out' || status == 'completed';

  /// Returns true if this attendance record is for the device's current calendar day.
  bool get isToday {
    if (date.isEmpty) return true;
    final today = DateTime.now();
    final recordDate = DateTime.tryParse(date);
    if (recordDate != null) {
      return recordDate.year == today.year &&
          recordDate.month == today.month &&
          recordDate.day == today.day;
    }
    final dayPart = date.contains('T') ? date.split('T').first : date;
    final parts = dayPart.split('-');
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null) {
        return y == today.year && m == today.month && d == today.day;
      }
    }
    // Lenient: unknown format on /today payload — still drive UI from times/status
    return true;
  }

  /// Returns true if attendance has valid complete cycle
  bool get hasValidAttendance {
    return (checkInTime != null && checkOutTime != null) ||
        status == 'completed';
  }

  /// Returns true if checked in but not checked out
  bool get isIncomplete => isCheckedIn && !isCheckedOut;

  String get _statusNorm => status.toLowerCase().trim();

  /// API: no shift assigned or explicit `no_shift` — check-in/out return 422.
  bool get hasNoShift =>
      _statusNorm == 'no_shift' || hasShiftAssigned == false;

  /// Both check-in and check-out are done (times and/or API status).
  bool get isAttendanceFlowCompleted {
    if (checkInTime != null && checkOutTime != null) return true;
    return _statusNorm == 'checked_out' || _statusNorm == 'completed';
  }

  /// Checked in for today but checkout still required.
  bool get needsCheckOut {
    if (isAttendanceFlowCompleted) return false;
    return checkInTime != null || _statusNorm == 'checked_in';
  }

  /// Safe status for UI: `no_shift` → pending → checked_in → completed.
  String get safeStatus {
    if (hasNoShift) return 'no_shift';
    if (!isToday) return 'pending';
    if (isAttendanceFlowCompleted) return 'completed';
    if (needsCheckOut) return 'checked_in';
    return 'pending';
  }
}

class AttendanceRecord {
  final String userId;
  final String id;
  final String date; // '2025-01-20'
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final double? durationHours;
  final String status; // 'present', 'late', 'early_leave', 'absent', 'half_day'
  final String? locationIn;
  final String? locationOut;
  final DateTime createdAt;
  final User? user; // for admin all-users view

  AttendanceRecord({
    required this.userId,
    required this.id,
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    this.durationHours,
    required this.status,
    this.locationIn,
    this.locationOut,
    required this.createdAt,
    this.user,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> raw) {
    final json = _unwrapAttendanceRecordJson(raw);
    return AttendanceRecord(
      userId: (json['userId'] ?? json['user_id'] ?? '').toString(),
      id: (json['id'] ?? json['_id'])?.toString() ?? '',
      date: (json['date'] ?? '').toString(),
      checkInTime: _parseAttendanceDateTime(
        json['checkInTime'] ?? json['check_in_time'],
      ),
      checkOutTime: _parseAttendanceDateTime(
        json['checkOutTime'] ?? json['check_out_time'],
      ),
      durationHours: _optionalRecordDouble(
        json['durationHours'] ?? json['duration_hours'],
      ),
      status: (json['status'] ?? 'absent').toString(),
      locationIn: _pickLocationFromJson(
        json,
        const [
          'locationIn',
          'location_in',
          'checkInLocation',
          'check_in_location',
          'inLocation',
          'in_location',
        ],
      ),
      locationOut: _pickLocationFromJson(
        json,
        const [
          'locationOut',
          'location_out',
          'checkOutLocation',
          'check_out_location',
          'outLocation',
          'out_location',
        ],
      ),
      createdAt: _parseAttendanceDateTime(
            json['createdAt'] ?? json['created_at'],
          ) ??
          DateTime.now(),
      user: json['user'] != null && json['user'] is Map
          ? User.fromJson(Map<String, dynamic>.from(json['user'] as Map))
          : null,
    );
  }
}

Map<String, dynamic> _unwrapAttendanceRecordJson(Map<String, dynamic> raw) {
  final inner = raw['data'] ?? raw['record'] ?? raw['attendance'];
  if (inner is Map) {
    return Map<String, dynamic>.from(inner);
  }
  return raw;
}

String? _pickLocationFromJson(
  Map<String, dynamic> json,
  List<String> keys,
) {
  for (final key in keys) {
    final v = json[key];
    if (v == null) continue;
    final s = v is String ? v : v.toString();
    final t = s.trim();
    if (t.isNotEmpty) return t;
  }
  return null;
}

double? _optionalRecordDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString());
}
