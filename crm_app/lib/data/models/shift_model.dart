import '../../core/json_parse.dart';
import 'attendance_model.dart';

/// Work shift from `GET/POST/PUT /api/shifts`. `weekendDays`: 0=Mon … 6=Sun (Postman).
class WorkShift {
  WorkShift({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.weekendDays,
    required this.gracePeriod,
    required this.employeeIds,
  });

  final String id;
  final String name;
  final String startTime;
  final String endTime;
  final List<int> weekendDays;
  final int gracePeriod;
  final List<String> employeeIds;

  factory WorkShift.fromJson(Map<String, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    final wd = json['weekendDays'] ?? json['weekend_days'];
    final emp =
        json['employeeIds'] ??
        json['employee_ids'] ??
        json['employees'] ??
        json['members'] ??
        json['userIds'] ??
        json['user_ids'];

    final workingHours = json['workingHours'] ?? json['working_hours'];
    Map<String, dynamic>? whMap;
    if (workingHours is Map) {
      whMap = Map<String, dynamic>.from(workingHours);
    }
    final scheduleRaw = json['schedule'] ?? json['timetable'] ?? json['slot'];
    Map<String, dynamic>? scheduleMap;
    if (scheduleRaw is Map) {
      scheduleMap = Map<String, dynamic>.from(scheduleRaw);
    }

    String start = _pickTimeLike(json, whMap, scheduleMap, isStart: true);
    String end = _pickTimeLike(json, whMap, scheduleMap, isStart: false);
    if (start.isEmpty || end.isEmpty) {
      final split = _splitCombinedTimeRange(json, whMap, scheduleMap);
      if (split != null) {
        if (start.isEmpty) start = split.$1;
        if (end.isEmpty) end = split.$2;
      }
    }
    if (start.isEmpty) {
      start = _rawTimeDynamic(json, whMap, scheduleMap, isStart: true);
    }
    if (end.isEmpty) {
      end = _rawTimeDynamic(json, whMap, scheduleMap, isStart: false);
    }
    start = shiftTimeFromApiValue(start);
    end = shiftTimeFromApiValue(end);
    String name = _pickFirstString(json, const [
      'name',
      'title',
      'label',
      'shiftName',
      'shift_name',
    ]);

    return WorkShift(
      id: _parseShiftDocumentId(json['id'] ?? json['_id']),
      name: name,
      startTime: start,
      endTime: end,
      weekendDays: wd is List
          ? wd.map((e) => int.tryParse(e.toString()) ?? 0).toList()
          : const [],
      gracePeriod: int.tryParse(
            (json['gracePeriod'] ?? json['grace_period'] ?? 0).toString(),
          ) ??
          0,
      employeeIds: _parseEmployeeIds(emp),
    );
  }

  static String _pickFirstString(Map<String, dynamic> json, List<String> keys) {
    for (final k in keys) {
      final v = json[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  /// Skips [Map]/[List] so Mongo date objects are not stringified into garbage.
  static String _scalarTrim(dynamic v) {
    if (v == null || v is Map || v is List) return '';
    return v.toString().trim();
  }

  /// Start/end from root [json], [workingHours], and [schedule] maps.
  static String _pickTimeLike(
    Map<String, dynamic> json,
    Map<String, dynamic>? workingHours,
    Map<String, dynamic>? schedule, {
    required bool isStart,
  }) {
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
      'checkIn',
      'check_in',
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
      'checkOut',
      'check_out',
      'finish',
    ];
    final keys = isStart ? startKeys : endKeys;
    for (final map in [json, workingHours, schedule]) {
      if (map == null) continue;
      for (final k in keys) {
        final s = _scalarTrim(map[k]);
        if (s.isNotEmpty) return s;
      }
    }
    return '';
  }

  /// Dynamic time (ISO, Mongo date map) — not yet normalized.
  static String _rawTimeDynamic(
    Map<String, dynamic> json,
    Map<String, dynamic>? workingHours,
    Map<String, dynamic>? schedule, {
    required bool isStart,
  }) {
    final startKeys = [
      'startTime',
      'start_time',
      'start',
      'shiftStart',
      'shift_start',
      'openTime',
      'open_time',
    ];
    final endKeys = [
      'endTime',
      'end_time',
      'end',
      'shiftEnd',
      'shift_end',
      'closeTime',
      'close_time',
    ];
    final keys = isStart ? startKeys : endKeys;
    for (final map in [json, workingHours, schedule]) {
      if (map == null) continue;
      for (final k in keys) {
        final v = map[k];
        if (v == null) continue;
        if (v is Map) {
          final m = Map<String, dynamic>.from(v);
          final d = m[r'$date'] ?? m['date'];
          if (d != null) return d.toString();
        }
        final s = v.toString().trim();
        if (s.isNotEmpty && s != 'null') return s;
      }
    }
    return '';
  }

  static (String, String)? _splitCombinedTimeRange(
    Map<String, dynamic> json,
    Map<String, dynamic>? workingHours,
    Map<String, dynamic>? schedule,
  ) {
    const rangeKeys = [
      'timeRange',
      'time_range',
      'hours',
      'window',
      'slot',
      'period',
    ];
    for (final map in [json, workingHours, schedule]) {
      if (map == null) continue;
      for (final k in rangeKeys) {
        final v = map[k];
        if (v is! String) continue;
        final s = v.trim();
        if (s.isEmpty) continue;
        final parts = s.split(RegExp(r'\s*[-–—]\s*'));
        if (parts.length == 2) {
          final a = parts[0].trim();
          final b = parts[1].trim();
          if (a.isNotEmpty && b.isNotEmpty) return (a, b);
        }
      }
    }
    return null;
  }

  /// True if [fromJson] produced something displayable.
  /// Name alone is not enough — user profiles also have `name` (would show as "shift").
  static bool looksPopulated(WorkShift w) {
    final st = w.startTime.trim();
    final et = w.endTime.trim();
    if (st.isNotEmpty && et.isNotEmpty) return true;
    final n = w.name.trim();
    if (n.isEmpty) return false;
    if (st.isNotEmpty || et.isNotEmpty) return true;
    return w.gracePeriod > 0 ||
        w.weekendDays.isNotEmpty ||
        w.employeeIds.isNotEmpty ||
        w.id.trim().isNotEmpty;
  }

  /// Nested `shift` / `assignedShift` on user (or me) payloads.
  static WorkShift? tryParseFromUserPayload(Map<String, dynamic>? root) {
    if (root == null || root.isEmpty) return null;
    var m = Map<String, dynamic>.from(root);
    for (final wrap in ['data', 'user', 'payload']) {
      final v = m[wrap];
      if (v is Map) {
        m = Map<String, dynamic>.from(v);
        break;
      }
    }
    for (final key in [
      'shift',
      'assignedShift',
      'assigned_shift',
      'workShift',
      'work_shift',
      'employeeShift',
      'employee_shift',
      'currentShift',
      'current_shift',
      'shiftTemplate',
      'shift_template',
      'roster',
    ]) {
      final v = m[key];
      if (v is Map) {
        try {
          final w = WorkShift.fromJson(Map<String, dynamic>.from(v));
          if (looksPopulated(w)) return w;
        } catch (_) {}
      }
    }
    return null;
  }

  static String? parseShiftIdFromUserPayload(Map<String, dynamic>? root) {
    if (root == null || root.isEmpty) return null;
    var m = Map<String, dynamic>.from(root);
    for (final wrap in ['data', 'user', 'payload']) {
      final v = m[wrap];
      if (v is Map) {
        m = Map<String, dynamic>.from(v);
        break;
      }
    }
    var sid = _pickFirstString(m, const [
      'shiftId',
      'shift_id',
      'assignedShiftId',
      'assigned_shift_id',
      'currentShiftId',
      'current_shift_id',
      'workShiftId',
      'work_shift_id',
      'templateShiftId',
      'template_shift_id',
      'shiftTemplateId',
      'shift_template_id',
    ]);
    if (sid.isEmpty) {
      final sv = m['shift'];
      if (sv is String && sv.trim().isNotEmpty) {
        sid = sv.trim();
      }
    }
    return sid.isEmpty ? null : sid;
  }

  static String _parseShiftDocumentId(dynamic v) {
    if (v == null) return '';
    if (v is String) return v.trim();
    if (v is Map) {
      final o = v[r'$oid'] ?? v['oid'];
      if (o != null) return o.toString().trim();
    }
    return v.toString().trim();
  }

  static List<String> _parseEmployeeIds(dynamic emp) {
    if (emp is! List) return const [];
    final out = <String>[];
    for (final e in emp) {
      if (e is Map) {
        final m = Map<String, dynamic>.from(e);
        final id = (m['id'] ?? m['_id'] ?? m['userId'] ?? m['user_id'])
            ?.toString()
            .trim();
        if (id != null && id.isNotEmpty) out.add(id);
        final mail = m['email']?.toString().trim();
        if (mail != null && mail.isNotEmpty) out.add(mail);
      } else {
        final s = e.toString().trim();
        if (s.isNotEmpty) out.add(s);
      }
    }
    return out;
  }

  Map<String, dynamic> toJsonBody() {
    return {
      'name': name,
      'startTime': startTime,
      'endTime': endTime,
      'weekendDays': weekendDays,
      'gracePeriod': gracePeriod,
      'employeeIds': employeeIds,
    };
  }

  static String _norm(String? s) => (s ?? '').trim().toLowerCase();

  /// Merge `employeeIds` from [detail] (e.g. `GET /shifts/:id`) into [base] when the list
  /// endpoint omitted the roster. Preserves order: [base] first, then new ids from [detail].
  static WorkShift mergeRosterFromDetail(WorkShift base, WorkShift? detail) {
    if (detail == null || detail.employeeIds.isEmpty) return base;
    final merged = _mergeEmployeeIdLists(base.employeeIds, detail.employeeIds);
    if (merged.length == base.employeeIds.length) {
      var same = true;
      for (var i = 0; i < merged.length; i++) {
        if (_norm(merged[i]) != _norm(base.employeeIds[i])) {
          same = false;
          break;
        }
      }
      if (same) return base;
    }
    return WorkShift(
      id: base.id,
      name: _preferNonEmptyString(base.name, detail.name),
      startTime: _preferNonEmptyString(base.startTime, detail.startTime),
      endTime: _preferNonEmptyString(base.endTime, detail.endTime),
      weekendDays:
          base.weekendDays.isNotEmpty ? base.weekendDays : detail.weekendDays,
      gracePeriod: base.gracePeriod != 0 ? base.gracePeriod : detail.gracePeriod,
      employeeIds: merged,
    );
  }

  static String _preferNonEmptyString(String a, String b) {
    if (a.trim().isNotEmpty) return a;
    return b;
  }

  /// When `GET /shifts/:id` and `/users/me` both return the same template, merge fields
  /// so a shell prefetch (missing times) does not hide a populated profile shift.
  static WorkShift mergeWithSameId(WorkShift a, WorkShift b) {
    if (a.id.trim().isEmpty || b.id.trim().isEmpty) return a;
    if (_norm(a.id) != _norm(b.id)) return a;
    return WorkShift(
      id: a.id,
      name: _preferNonEmptyString(a.name, b.name),
      startTime: _preferNonEmptyString(a.startTime, b.startTime),
      endTime: _preferNonEmptyString(a.endTime, b.endTime),
      weekendDays:
          a.weekendDays.isNotEmpty ? a.weekendDays : b.weekendDays,
      gracePeriod: a.gracePeriod != 0 ? a.gracePeriod : b.gracePeriod,
      employeeIds: a.employeeIds.isNotEmpty ? a.employeeIds : b.employeeIds,
    );
  }

  static List<String> _mergeEmployeeIdLists(List<String> a, List<String> b) {
    if (b.isEmpty) return a;
    final seen = <String>{};
    final out = <String>[];
    for (final x in a) {
      final k = _norm(x);
      if (k.isEmpty) continue;
      if (seen.add(k)) out.add(x.trim());
    }
    for (final x in b) {
      final k = _norm(x);
      if (k.isEmpty) continue;
      if (seen.add(k)) out.add(x.trim());
    }
    return out;
  }

  /// Picks the shift to show — **server data only** (no clock/check-in guessing).
  ///
  /// Order: template id from `/attendance/today` → [shiftIdFromAuthUser] (`User.shiftId`)
  /// → merge [prefetchedByTemplateId] + [profileShift] when same id → prefetched with times
  /// → [profileShift] → roster [forUser].
  ///
  /// If null, call [fromAttendanceDaySnapshot] when the API embeds shift text on the row.
  static WorkShift? resolveAttendanceShift({
    required List<WorkShift> shifts,
    String? assignedShiftIdFromToday,
    String? shiftIdFromAuthUser,
    String? userId,
    String? userEmail,
    WorkShift? profileShift,
    WorkShift? prefetchedByTemplateId,
  }) {
    WorkShift? pre = prefetchedByTemplateId;
    final prof = profileShift;
    if (pre != null && prof != null) {
      pre = mergeWithSameId(pre, prof);
    }

    for (final raw in [assignedShiftIdFromToday, shiftIdFromAuthUser]) {
      final id = raw?.trim();
      if (id != null && id.isNotEmpty) {
        final hit = byId(id, shifts);
        if (hit != null) return hit;
      }
    }

    final wanted = assignedShiftIdFromToday?.trim() ??
        shiftIdFromAuthUser?.trim() ??
        '';

    if (pre != null) {
      final pid = pre.id.trim();
      final idOk = wanted.isEmpty || _norm(pid) == _norm(wanted);
      if (idOk) {
        final st = pre.startTime.trim();
        final et = pre.endTime.trim();
        if (st.isNotEmpty && et.isNotEmpty) {
          return pre;
        }
      }
    }

    if (prof != null) {
      final pid = prof.id.trim();
      if (pid.isNotEmpty) {
        final listed = byId(pid, shifts);
        if (listed != null) return listed;
      }
      if (looksPopulated(prof)) return prof;
    }

    return forUser(
      userId,
      shifts,
      userEmail: userEmail,
      atLocal: null,
    );
  }

  /// Display-only shift from `/attendance/today` snapshot fields (authoritative copy from API).
  static WorkShift? fromAttendanceDaySnapshot(TodayAttendance? t) {
    if (t == null) return null;
    final name = t.shiftName?.trim() ?? '';
    final a = t.shiftStartTime?.trim() ?? '';
    final b = t.shiftEndTime?.trim() ?? '';
    if (name.isEmpty && (a.isEmpty || b.isEmpty)) return null;
    final id = t.assignedShiftId?.trim() ?? '';
    return WorkShift(
      id: id,
      name: name.isNotEmpty ? name : 'Shift',
      startTime: a,
      endTime: b,
      weekendDays: const [],
      gracePeriod: t.shiftGraceMinutes ?? 0,
      employeeIds: const [],
    );
  }

  /// Shift whose id matches [shiftId] (case-insensitive).
  static WorkShift? byId(String? shiftId, List<WorkShift> shifts) {
    if (shiftId == null || shiftId.trim().isEmpty) return null;
    final key = _norm(shiftId);
    for (final s in shifts) {
      if (_norm(s.id) == key) return s;
    }
    return null;
  }

  /// [mins] is minutes from midnight (local). End is exclusive for same-day windows.
  static bool _minuteInsideWindow(int mins, WorkShift s) {
    final a = _clockMinutes(s.startTime);
    final b = _clockMinutes(s.endTime);
    if (a == null || b == null) return false;
    if (a <= b) {
      return mins >= a && mins < b;
    }
    return mins >= a || mins < b;
  }

  static int? _clockMinutes(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final segs = t.split(':');
    if (segs.length < 2) return null;
    final h = int.tryParse(segs[0].trim());
    final m = int.tryParse(segs[1].trim());
    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return h * 60 + m;
  }

  /// Shifts listing this user by id or email in [employeeIds] (case-insensitive).
  ///
  /// If [atLocal] is set and several shifts match, prefers those whose window contains
  /// [atLocal]; if still several, uses the first in [shifts] order. If [atLocal] is null,
  /// returns the first roster match (GET /shifts list order).
  static WorkShift? forUser(
    String? userId,
    List<WorkShift> shifts, {
    String? userEmail,
    DateTime? atLocal,
  }) {
    final candidates = <WorkShift>[];
    final seen = <String>{};
    void add(WorkShift s) {
      final k = s.id.trim().toLowerCase();
      if (k.isEmpty) return;
      if (seen.add(k)) candidates.add(s);
    }

    final u = _norm(userId);
    if (u.isNotEmpty) {
      for (final s in shifts) {
        for (final e in s.employeeIds) {
          if (_norm(e) == u) {
            add(s);
            break;
          }
        }
      }
    }
    final em = _norm(userEmail);
    if (em.isNotEmpty) {
      for (final s in shifts) {
        for (final e in s.employeeIds) {
          if (_norm(e) == em) {
            add(s);
            break;
          }
        }
      }
    }

    if (candidates.isEmpty) return null;
    if (candidates.length == 1) return candidates.first;

    if (atLocal == null) {
      return candidates.first;
    }

    final mins = atLocal.toLocal().hour * 60 + atLocal.toLocal().minute;
    final inWindow =
        candidates.where((s) => _minuteInsideWindow(mins, s)).toList();
    if (inWindow.length == 1) return inWindow.first;
    if (inWindow.length > 1) {
      for (final s in shifts) {
        for (final w in inWindow) {
          if (_norm(s.id) == _norm(w.id)) return s;
        }
      }
      return inWindow.first;
    }
    return candidates.first;
  }

  static String weekdayLabel(int i) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (i >= 0 && i < names.length) return names[i];
    return '$i';
  }

  String get weekendDaysLabel {
    if (weekendDays.isEmpty) return '—';
    return weekendDays.map(weekdayLabel).join(', ');
  }
}
