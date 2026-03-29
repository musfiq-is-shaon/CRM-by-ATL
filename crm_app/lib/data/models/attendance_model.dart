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
  final String status; // 'pending', 'checked_in', 'checked_out', 'completed'
  final String date; // '2025-01-20'
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final bool isLate;
  final int? lateMinutes;
  final double? totalHours;
  final String? locationIn;
  final String? locationOut;

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
  });

  factory TodayAttendance.fromJson(dynamic raw) {
    final json = _unwrapTodayJson(raw);
    final checkInTime = _parseAttendanceDateTime(
      json['checkInTime'] ?? json['check_in_time'],
    );
    final checkOutTime = _parseAttendanceDateTime(
      json['checkOutTime'] ?? json['check_out_time'],
    );
    return TodayAttendance(
      userId: (json['userId'] ?? json['user_id'] ?? '').toString(),
      status: json['status'] ?? 'pending',
      date: (json['date'] ?? '').toString(),
      checkInTime: checkInTime,
      checkOutTime: checkOutTime,
      isLate: json['isLate'] ?? json['is_late'] ?? false,
      lateMinutes: _optionalInt(json['lateMinutes'] ?? json['late_minutes']),
      totalHours: _optionalDouble(json['totalHours'] ?? json['total_hours']),
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

  /// Safe status for UI: pending → checked_in (still pending day) → completed.
  String get safeStatus {
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
