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
    final emp = json['employeeIds'] ?? json['employee_ids'];
    return WorkShift(
      id: (json['id'] ?? json['_id'])?.toString() ?? '',
      name: (json['name'] ?? '').toString(),
      startTime: (json['startTime'] ?? json['start_time'] ?? '').toString(),
      endTime: (json['endTime'] ?? json['end_time'] ?? '').toString(),
      weekendDays: wd is List
          ? wd.map((e) => int.tryParse(e.toString()) ?? 0).toList()
          : const [],
      gracePeriod: int.tryParse(
            (json['gracePeriod'] ?? json['grace_period'] ?? 0).toString(),
          ) ??
          0,
      employeeIds: emp is List
          ? emp.map((e) => e.toString()).toList()
          : const [],
    );
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

  /// First shift that lists [userId] in [employeeIds].
  static WorkShift? forUser(String? userId, List<WorkShift> shifts) {
    if (userId == null || userId.isEmpty) return null;
    for (final s in shifts) {
      if (s.employeeIds.contains(userId)) return s;
    }
    return null;
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
