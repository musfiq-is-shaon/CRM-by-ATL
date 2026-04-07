import '../../core/json_parse.dart';
import 'user_model.dart';

/// API sends ISO-8601; UTC (`Z` / offset) must become local for display.
DateTime? _parseAttendanceDateTime(dynamic raw) {
  if (raw == null) return null;
  final parsed = DateTime.tryParse(raw.toString());
  if (parsed == null) return null;
  return parsed.isUtc ? parsed.toLocal() : parsed;
}

Map<String, dynamic>? _mapFromDynamic(dynamic v) {
  if (v is Map) return Map<String, dynamic>.from(v);
  return null;
}

/// First nested map that looks like a shift payload on `/attendance/today`.
Map<String, dynamic>? _shiftSnapshotMap(Map<String, dynamic> json) {
  const wrapperKeys = [
    'shift',
    'shiftInfo',
    'shift_info',
    'assignedShift',
    'assigned_shift',
    'currentShift',
    'current_shift',
    'workShift',
    'work_shift',
    'employeeShift',
    'employee_shift',
    'shiftDetails',
    'shift_details',
    'roster',
    'schedule',
    'expectedShift',
    'expected_shift',
    'plannedShift',
    'planned_shift',
    'shiftTemplate',
    'shift_template',
  ];
  for (final k in wrapperKeys) {
    final inner = _mapFromDynamic(json[k]);
    if (inner != null && inner.isNotEmpty) return inner;
  }
  for (final top in ['user', 'employee', 'profile']) {
    final u = _mapFromDynamic(json[top]);
    if (u == null) continue;
    for (final k in wrapperKeys) {
      final inner = _mapFromDynamic(u[k]);
      if (inner != null && inner.isNotEmpty) return inner;
    }
  }
  return null;
}

String? _firstNonEmptyString(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return null;
}

/// Reads shift start/end from nested `/attendance/today` maps (ISO, Mongo date, `HH:mm`).
String? _shiftTimeFromSnapshotMap(Map<String, dynamic> m, bool isStart) {
  final startKeys = [
    'startTime',
    'start_time',
    'start',
    'shiftStart',
    'shift_start',
    'from',
    'opensAt',
    'opens_at',
    'openTime',
    'open_time',
    'begin',
  ];
  final endKeys = [
    'endTime',
    'end_time',
    'end',
    'shiftEnd',
    'shift_end',
    'to',
    'closesAt',
    'closes_at',
    'closeTime',
    'close_time',
    'finish',
  ];
  final keys = isStart ? startKeys : endKeys;
  for (final k in keys) {
    final v = m[k];
    if (v == null) continue;
    final s = shiftTimeFromApiValue(v);
    if (s.isNotEmpty) return s;
  }
  return null;
}

/// Mongo extended JSON `{"$oid":"..."}` or plain string — for `id` / shift ids.
String? _firstIdString(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    final s = _idStringFromDynamic(v);
    if (s.isNotEmpty) return s;
  }
  return null;
}

String _idStringFromDynamic(dynamic v) {
  if (v == null) return '';
  if (v is String) return v.trim();
  if (v is Map) {
    final o = v[r'$oid'] ?? v['oid'];
    if (o != null) return o.toString().trim();
    final nested = v['id'] ?? v['_id'];
    if (nested != null) return _idStringFromDynamic(nested);
  }
  final t = v.toString().trim();
  return t == 'null' ? '' : t;
}

/// Compare user ids from API (hex, Mongo wrappers, case-insensitive).
bool attendanceUserIdsEqual(String? a, String? b) {
  final x = _idStringFromDynamic(a);
  final y = _idStringFromDynamic(b);
  if (x.isEmpty || y.isEmpty) return false;
  return x.toLowerCase() == y.toLowerCase();
}

String _reconciliationApplicantUserId(
  Map<String, dynamic> json,
  User? embeddedUser,
) {
  for (final k in [
    'userId',
    'user_id',
    'applicantId',
    'applicant_id',
    'employeeId',
    'employee_id',
  ]) {
    final s = _idStringFromDynamic(json[k]);
    if (s.isNotEmpty) return s;
  }
  if (embeddedUser != null) {
    final s = _idStringFromDynamic(embeddedUser.id);
    if (s.isNotEmpty) return s;
  }
  return '';
}

/// Parses [shiftDisplay] as `HH:mm`, `HH:mm:ss`, or `h:mm AM/PM` on [date]'s calendar day.
///
/// Public for scheduling (e.g. shift-start local notifications).
DateTime? attendanceDateAtShiftClock(DateTime date, String shiftDisplay) =>
    _combineLocalDateWithShiftDisplay(date, shiftDisplay);

DateTime? _combineLocalDateWithShiftDisplay(
  DateTime date,
  String shiftDisplay,
) {
  final t = shiftDisplay.trim();
  if (t.isEmpty) return null;
  final m24 = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$').firstMatch(t);
  if (m24 != null) {
    final h = int.tryParse(m24.group(1)!);
    final min = int.tryParse(m24.group(2)!);
    if (h == null || min == null || h >= 24 || min >= 60) return null;
    return DateTime(date.year, date.month, date.day, h, min);
  }
  final m12 = RegExp(
    r'^(\d{1,2}):(\d{2})\s*(AM|PM)',
    caseSensitive: false,
  ).firstMatch(t);
  if (m12 != null) {
    var h = int.tryParse(m12.group(1)!);
    final min = int.tryParse(m12.group(2)!);
    final ap = m12.group(3)!.toUpperCase();
    if (h == null || min == null || h < 1 || h > 12 || min >= 60) {
      return null;
    }
    if (ap == 'PM' && h != 12) h += 12;
    if (ap == 'AM' && h == 12) h = 0;
    return DateTime(date.year, date.month, date.day, h, min);
  }
  return null;
}

int? _inferLateMinutesFromShiftFields({
  required DateTime? checkInTime,
  required String? shiftStartDisplay,
  required int? shiftGraceMinutes,
}) {
  final cin = checkInTime;
  if (cin == null) return null;
  final raw = shiftStartDisplay?.trim();
  if (raw == null || raw.isEmpty) return null;
  final scheduled = _combineLocalDateWithShiftDisplay(cin, raw);
  if (scheduled == null) return null;
  final grace = shiftGraceMinutes ?? 0;
  final allowedEnd = scheduled.add(Duration(minutes: grace));
  if (!cin.isAfter(allowedEnd)) return null;
  return cin.difference(allowedEnd).inMinutes;
}

/// Root + one wrapper level only — avoids false "late" from unrelated nested keys.
int? _lateMinutesFromCheckInShallow(dynamic raw) {
  int? found;
  void take(Map<String, dynamic> m) {
    final lm = TodayAttendance._optionalInt(
      m['lateMinutes'] ?? m['late_minutes'],
    );
    if (lm != null && lm > 0) found = lm;
  }

  if (raw is Map) {
    final m = Map<String, dynamic>.from(raw);
    take(m);
    for (final key in [
      'data',
      'today',
      'attendance',
      'record',
      'result',
      'payload',
      'response',
      'body',
    ]) {
      final v = m[key];
      if (v is Map) take(Map<String, dynamic>.from(v));
    }
  }
  return found;
}

bool _lateSignalFromCheckInShallow(dynamic raw) {
  var late = false;
  void consider(Map<String, dynamic> m) {
    if (TodayAttendance._parseIsLateFlag(m)) late = true;
    final st = (m['status'] ?? '').toString().toLowerCase().trim();
    if (st == 'late') late = true;
    final ast = (m['attendanceStatus'] ?? m['attendance_status'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    if (ast == 'late') late = true;
  }

  if (raw is Map) {
    final m = Map<String, dynamic>.from(raw);
    consider(m);
    for (final key in [
      'data',
      'today',
      'attendance',
      'record',
      'result',
      'payload',
      'response',
      'body',
    ]) {
      final v = m[key];
      if (v is Map) consider(Map<String, dynamic>.from(v));
    }
  }
  return late;
}

class TodayAttendance {
  /// Attendance **record** id (reconciliations, etc.). Same as root `id` and
  /// `lateReconciliation.attendanceId` on GET /attendance/today — **not** the shift template id from GET /shifts.
  final String? id;
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
  /// Shift template id from `/attendance/today` when embedded shift or `shiftId` is sent.
  final String? assignedShiftId;

  TodayAttendance({
    this.id,
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
    this.assignedShiftId,
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
    final shiftMap = _shiftSnapshotMap(json);
    if (shiftMap != null) {
      shiftName = _firstNonEmptyString(shiftMap, const [
        'name',
        'title',
        'label',
        'shiftName',
        'shift_name',
      ]);
      shiftStart = _shiftTimeFromSnapshotMap(shiftMap, true);
      shiftEnd = _shiftTimeFromSnapshotMap(shiftMap, false);
      shiftGrace = _optionalInt(
        shiftMap['gracePeriod'] ??
            shiftMap['grace_period'] ??
            shiftMap['graceMinutes'] ??
            shiftMap['grace_minutes'],
      );
    }
    shiftName ??= json['shiftName']?.toString() ?? json['shift_name']?.toString();
    if (shiftStart?.trim().isEmpty ?? true) {
      final r = shiftTimeFromApiValue(
        json['shiftStartTime'] ?? json['shift_start_time'],
      );
      if (r.isNotEmpty) shiftStart = r;
    }
    if (shiftEnd?.trim().isEmpty ?? true) {
      final r = shiftTimeFromApiValue(
        json['shiftEndTime'] ?? json['shift_end_time'],
      );
      if (r.isNotEmpty) shiftEnd = r;
    }
    shiftGrace ??= _optionalInt(json['shiftGraceMinutes'] ?? json['shift_grace_minutes']);

    String? assignedShiftId = _firstNonEmptyString(json, const [
      'shiftId',
      'shift_id',
      'assignedShiftId',
      'assigned_shift_id',
      'currentShiftId',
      'current_shift_id',
      'templateShiftId',
      'template_shift_id',
      'shiftTemplateId',
      'shift_template_id',
      'workShiftId',
      'work_shift_id',
    ]);
    if (assignedShiftId == null && shiftMap != null) {
      assignedShiftId = _firstNonEmptyString(shiftMap, const [
        'shiftId',
        'shift_id',
      ]) ??
          _firstIdString(shiftMap, const ['id', '_id']);
    }
    final shiftRaw = json['shift'];
    if (assignedShiftId == null &&
        shiftRaw is String &&
        shiftRaw.trim().isNotEmpty) {
      assignedShiftId = shiftRaw.trim();
    }
    // Root `id` on /attendance/today is the **attendance row** id (same as lateReconciliation.attendanceId),
    // not a template id from GET /shifts — do not use it for [assignedShiftId].

    if (assignedShiftId == null || assignedShiftId.trim().isEmpty) {
      for (final uk in ['user', 'employee', 'profile', 'staff', 'member']) {
        final u = _mapFromDynamic(json[uk]);
        if (u == null) continue;
        var sid = _firstNonEmptyString(u, const [
          'shiftId',
          'shift_id',
          'assignedShiftId',
          'assigned_shift_id',
          'currentShiftId',
          'current_shift_id',
        ]);
        if (sid == null || sid.isEmpty) {
          for (final sk in [
            'shift',
            'assignedShift',
            'assigned_shift',
            'workShift',
            'work_shift',
          ]) {
            final sh = _mapFromDynamic(u[sk]);
            if (sh == null) continue;
            sid = _firstNonEmptyString(sh, const [
                  'id',
                  '_id',
                  'shiftId',
                  'shift_id',
                ]) ??
                _firstIdString(sh, const ['id', '_id']);
            if (sid != null && sid.isNotEmpty) break;
          }
        }
        if (sid != null && sid.isNotEmpty) {
          assignedShiftId = sid;
          break;
        }
      }
    }

    return TodayAttendance(
      id: _pickAttendanceRowId(json),
      userId: (json['userId'] ?? json['user_id'] ?? '').toString(),
      status: json['status'] ?? 'pending',
      date: (json['date'] ?? '').toString(),
      checkInTime: checkInTime,
      checkOutTime: checkOutTime,
      isLate: _parseIsLateFlag(json),
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
      assignedShiftId: assignedShiftId,
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

  static String? _pickAttendanceRowId(Map<String, dynamic> json) {
    final lr = json['lateReconciliation'] ?? json['late_reconciliation'];
    if (lr is Map) {
      final aid = _idStringFromDynamic(
        lr['attendanceId'] ?? lr['attendance_id'],
      );
      if (aid.isNotEmpty) return aid;
    }
    final keys = [
      'attendanceId',
      'attendance_id',
      'recordId',
      'record_id',
      'uuid',
      'id',
      '_id',
    ];
    for (final key in keys) {
      final v = json[key];
      final s = _idStringFromDynamic(v);
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  /// GET /attendance/today often returns before late flags are visible; POST /check-in may include them.
  TodayAttendance mergeLateHintsFromCheckIn(dynamic checkInBody) {
    final post = TodayAttendance.fromJson(checkInBody);
    var postLate = post.isLate ||
        (post.lateMinutes != null && post.lateMinutes! > 0) ||
        post.status.toLowerCase().trim() == 'late';
    int? shallowMins;
    if (!postLate) {
      if (_lateSignalFromCheckInShallow(checkInBody)) postLate = true;
      shallowMins = _lateMinutesFromCheckInShallow(checkInBody);
      if (shallowMins != null && shallowMins > 0) postLate = true;
    }
    if (!postLate) return this;
    final mergedMins = lateMinutes ?? post.lateMinutes ?? shallowMins;
    final inferred = _inferLateMinutesFromShiftFields(
      checkInTime: checkInTime ?? post.checkInTime,
      shiftStartDisplay: shiftStartTime ?? post.shiftStartTime,
      shiftGraceMinutes: shiftGraceMinutes ?? post.shiftGraceMinutes,
    );
    final finalMins = mergedMins ?? inferred;
    return TodayAttendance(
      id: (id != null && id!.trim().isNotEmpty) ? id : post.id,
      userId: userId.isNotEmpty ? userId : post.userId,
      status: status.isNotEmpty ? status : post.status,
      date: date.isNotEmpty ? date : post.date,
      checkInTime: checkInTime ?? post.checkInTime,
      checkOutTime: checkOutTime ?? post.checkOutTime,
      isLate: true,
      lateMinutes: finalMins,
      totalHours: totalHours ?? post.totalHours,
      locationIn: locationIn ?? post.locationIn,
      locationOut: locationOut ?? post.locationOut,
      hasShiftAssigned: hasShiftAssigned ?? post.hasShiftAssigned,
      isWeekend: isWeekend ?? post.isWeekend,
      isHoliday: isHoliday ?? post.isHoliday,
      shiftName: shiftName ?? post.shiftName,
      shiftStartTime: shiftStartTime ?? post.shiftStartTime,
      shiftEndTime: shiftEndTime ?? post.shiftEndTime,
      shiftGraceMinutes: shiftGraceMinutes ?? post.shiftGraceMinutes,
      assignedShiftId: assignedShiftId ?? post.assignedShiftId,
    );
  }

  /// [lateMinutes] from API, or inferred from check-in time vs shift start + grace when [isLate].
  /// Never returns 0 — only a positive minute count or null (no "null min" in UI).
  int? get resolvedLateMinutes {
    if (lateMinutes != null && lateMinutes! > 0) return lateMinutes;
    if (!isLate) return null;
    final inferred = _inferLateMinutesFromShiftFields(
      checkInTime: checkInTime,
      shiftStartDisplay: shiftStartTime,
      shiftGraceMinutes: shiftGraceMinutes,
    );
    if (inferred == null || inferred <= 0) return null;
    return inferred;
  }

  /// Late reconciliation popup: only when the server (or merged check-in body) actually marks this row late.
  bool get shouldPromptLateReconciliation {
    final st = status.toLowerCase().trim();
    if (st == 'late') return true;
    if (lateMinutes != null && lateMinutes! > 0) return true;
    if (isLate) return true;
    return false;
  }

  /// Same row with a resolved DB id (e.g. from check-in POST when GET /today omits `id`).
  TodayAttendance withAttendanceRowId(String rowId) {
    final t = rowId.trim();
    if (t.isEmpty) return this;
    return TodayAttendance(
      id: t,
      userId: userId,
      status: status,
      date: date,
      checkInTime: checkInTime,
      checkOutTime: checkOutTime,
      isLate: isLate,
      lateMinutes: lateMinutes,
      totalHours: totalHours,
      locationIn: locationIn,
      locationOut: locationOut,
      hasShiftAssigned: hasShiftAssigned,
      isWeekend: isWeekend,
      isHoliday: isHoliday,
      shiftName: shiftName,
      shiftStartTime: shiftStartTime,
      shiftEndTime: shiftEndTime,
      shiftGraceMinutes: shiftGraceMinutes,
      assignedShiftId: assignedShiftId,
    );
  }

  /// API may return `{ "data": { "today": { ... } } }` — drill until we see attendance fields.
  static Map<String, dynamic> _unwrapTodayJson(dynamic raw) {
    var node = raw;
    if (node is List && node.isNotEmpty) {
      final first = node.first;
      if (first is Map) {
        node = first;
      } else {
        return {};
      }
    }
    if (node is! Map) return {};
    var m = Map<String, dynamic>.from(node);
    for (var depth = 0; depth < 8; depth++) {
      if (_looksLikeTodayAttendanceDoc(m)) break;
      Map<String, dynamic>? inner;
      for (final key in [
        'data',
        'today',
        'attendance',
        'record',
        'result',
        'payload',
        'response',
        'body',
      ]) {
        final v = m[key];
        if (v is Map) {
          inner = Map<String, dynamic>.from(v);
          break;
        }
      }
      if (inner == null) break;
      m = inner;
    }
    return m;
  }

  static bool _looksLikeTodayAttendanceDoc(Map<String, dynamic> m) {
    return m.containsKey('status') ||
        m.containsKey('date') ||
        m.containsKey('checkInTime') ||
        m.containsKey('check_in_time') ||
        m.containsKey('checkOutTime') ||
        m.containsKey('check_out_time') ||
        m.containsKey('isLate') ||
        m.containsKey('is_late') ||
        m.containsKey('lateMinutes') ||
        m.containsKey('late_minutes') ||
        m.containsKey('hasShiftAssigned') ||
        m.containsKey('has_shift_assigned') ||
        m.containsKey('userId') ||
        m.containsKey('user_id');
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

  /// True when the server marks this check-in as late (flags, minutes, or status).
  static bool _parseIsLateFlag(Map<String, dynamic> json) {
    final flag = parseOptionalBool(json['isLate'] ?? json['is_late']);
    if (flag == true) return true;
    final lm = _optionalInt(json['lateMinutes'] ?? json['late_minutes']);
    if (lm != null && lm > 0) return true;
    var st = (json['status'] ?? '').toString().toLowerCase().trim();
    if (st == 'late') return true;
    st = (json['attendanceStatus'] ?? json['attendance_status'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    if (st == 'late') return true;
    return false;
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

int _lateMinutesFromAttendanceJson(Map<String, dynamic> json) {
  final v = json['lateMinutes'] ?? json['late_minutes'];
  if (v == null) return 0;
  if (v is int) return v;
  if (v is double) return v.round();
  return int.tryParse(v.toString()) ?? 0;
}

bool _isLateAttendanceJson(Map<String, dynamic> json) {
  if (json['isLate'] == true || json['is_late'] == true) return true;
  return _lateMinutesFromAttendanceJson(json) > 0;
}

/// Maps `/attendance/records` row status to UI + week rollup (`present`, `late`, …).
String _attendanceRecordStatusFromJson(Map<String, dynamic> json) {
  String raw = '';
  for (final k in [
    'status',
    'attendanceStatus',
    'attendance_status',
    'dayStatus',
    'day_status',
    'recordStatus',
    'record_status',
  ]) {
    final v = json[k];
    if (v == null) continue;
    final t = v.toString().trim();
    if (t.isNotEmpty && t != 'null') {
      raw = t;
      break;
    }
  }
  if (raw.isEmpty) return 'absent';

  var s = raw.toLowerCase().trim().replaceAll(' ', '_').replaceAll('-', '_');

  const canonical = {
    'present',
    'late',
    'absent',
    'early_leave',
    'half_day',
  };
  if (canonical.contains(s)) return s;

  if (s == 'completed' ||
      s == 'checked_out' ||
      s == 'done' ||
      s == 'full_day' ||
      s == 'fullday') {
    return _isLateAttendanceJson(json) ? 'late' : 'present';
  }

  if (s == 'on_time' || s == 'ontime') return 'present';

  if (s == 'checked_in') {
    final cin = _parseAttendanceDateTime(
      json['checkInTime'] ?? json['check_in_time'],
    );
    final cout = _parseAttendanceDateTime(
      json['checkOutTime'] ?? json['check_out_time'],
    );
    if (cin != null && cout != null) {
      return _isLateAttendanceJson(json) ? 'late' : 'present';
    }
  }

  if (s == 'pending' ||
      s == 'no_shift' ||
      s == 'no_show' ||
      s == 'noshow') {
    return 'absent';
  }

  return s;
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
      id: (json['id'] ??
              json['_id'] ??
              json['attendance_id'] ??
              json['attendanceId'])
          ?.toString() ??
          '',
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
      status: _attendanceRecordStatusFromJson(json),
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

/// Late check-in reconciliation request (`GET/POST /api/attendance/reconciliations`).
class AttendanceReconciliation {
  final String id;
  final String attendanceId;
  final String userId;
  final String? userName;
  final String reason;
  final String status; // pending | approved | rejected
  final String? reviewNote;
  final DateTime? createdAt;
  final DateTime? reviewedAt;
  final String? attendanceDate;
  final User? user;

  AttendanceReconciliation({
    required this.id,
    required this.attendanceId,
    required this.userId,
    this.userName,
    required this.reason,
    required this.status,
    this.reviewNote,
    this.createdAt,
    this.reviewedAt,
    this.attendanceDate,
    this.user,
  });

  factory AttendanceReconciliation.fromJson(Map<String, dynamic> raw) {
    final json = _unwrapReconciliationJson(raw);
    final u = json['user'];
    User? userObj;
    if (u is Map) {
      userObj = User.fromJson(Map<String, dynamic>.from(u));
    }
    final nameFromUser = userObj?.name;
    final applicantId = _reconciliationApplicantUserId(json, userObj);
    return AttendanceReconciliation(
      id: _idStringFromDynamic(json['id'] ?? json['_id']),
      attendanceId: _idStringFromDynamic(
        json['attendanceId'] ?? json['attendance_id'],
      ),
      userId: applicantId,
      userName: (json['userName'] ?? json['user_name'] ?? nameFromUser)
          ?.toString(),
      reason: (json['reason'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString().toLowerCase(),
      reviewNote: (json['reviewNote'] ?? json['review_note'])?.toString(),
      createdAt: _parseAttendanceDateTime(
        json['createdAt'] ?? json['created_at'],
      ),
      reviewedAt: _parseAttendanceDateTime(
        json['reviewedAt'] ?? json['reviewed_at'],
      ),
      attendanceDate:
          (json['date'] ?? json['attendanceDate'] ?? json['attendance_date'])
              ?.toString(),
      user: userObj,
    );
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  String get displayUserName =>
      userName?.trim().isNotEmpty == true
          ? userName!.trim()
          : (user?.name.trim().isNotEmpty == true ? user!.name : 'User');

  /// Applicant id with fallbacks if the row only embeds [user].
  String get effectiveApplicantUserId {
    final a = _idStringFromDynamic(userId);
    if (a.isNotEmpty) return a;
    if (user != null) {
      final b = _idStringFromDynamic(user!.id);
      if (b.isNotEmpty) return b;
    }
    return '';
  }
}

Map<String, dynamic> _unwrapReconciliationJson(Map<String, dynamic> raw) {
  final inner = raw['data'] ?? raw['item'] ?? raw['reconciliation'];
  if (inner is Map) {
    return Map<String, dynamic>.from(inner);
  }
  return raw;
}

List<Map<String, dynamic>> reconciliationsListFromResponse(dynamic body) {
  if (body is List) {
    return body
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  if (body is Map) {
    final m = Map<String, dynamic>.from(body);
    final list = m['data'] ??
        m['items'] ??
        m['results'] ??
        m['reconciliations'] ??
        m['list'];
    if (list is List) {
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
  }
  return [];
}

String _calendarDateOnly(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return '';
  if (t.contains('T')) return t.split('T').first;
  if (t.contains(' ')) return t.split(' ').first;
  return t;
}

/// True when two API date strings refer to the same calendar day.
bool attendanceDatesSameCalendarDay(String a, String b) {
  final ka = _calendarDateOnly(a);
  final kb = _calendarDateOnly(b);
  if (ka.isEmpty || kb.isEmpty) return ka == kb;
  return ka == kb;
}

/// Parses `id` from check-in/out POST JSON (Flask may nest under `data` / `attendance`).
String? extractAttendanceRowIdFromApiResponse(dynamic raw) {
  if (raw == null) return null;
  if (raw is! Map) return null;
  var m = Map<String, dynamic>.from(raw);
  for (final wrap in [
    'data',
    'attendance',
    'record',
    'result',
    'payload',
    'today',
    'response',
    'body',
  ]) {
    final v = m[wrap];
    if (v is Map) {
      final inner = Map<String, dynamic>.from(v);
      final id = TodayAttendance._pickAttendanceRowId(inner);
      if (id != null && id.isNotEmpty) return id;
    }
  }
  return TodayAttendance._pickAttendanceRowId(m);
}

/// Prefer [TodayAttendance.id], else match today's [AttendanceRecord.id] from API.
String? resolveTodayAttendanceRowId(
  TodayAttendance? today,
  List<AttendanceRecord> records,
) {
  final tid = today?.id?.trim();
  if (tid != null && tid.isNotEmpty) return tid;
  final dateKey = _calendarDateOnly(today?.date ?? '');
  if (dateKey.isNotEmpty) {
    for (final r in records) {
      if (_calendarDateOnly(r.date) == dateKey && r.id.isNotEmpty) {
        return r.id;
      }
    }
  }
  // `period=today` should yield at most one row; avoid picking a wrong day's id.
  if (records.length == 1) {
    final only = records.first.id.trim();
    if (only.isNotEmpty) return only;
  }
  return null;
}
