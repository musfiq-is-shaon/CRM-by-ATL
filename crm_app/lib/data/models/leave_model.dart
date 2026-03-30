DateTime? _parseLeaveDate(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString().trim();
  if (s.isEmpty) return null;
  final parsed = DateTime.tryParse(s);
  if (parsed != null) {
    return parsed.isUtc ? parsed.toLocal() : parsed;
  }
  final dateOnly = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
  if (dateOnly != null) {
    final y = int.tryParse(dateOnly.group(1)!);
    final m = int.tryParse(dateOnly.group(2)!);
    final d = int.tryParse(dateOnly.group(3)!);
    if (y != null && m != null && d != null) {
      return DateTime(y, m, d);
    }
  }
  return null;
}

/// How long the leave runs (drives which date fields are shown).
enum LeaveApplyDurationMode {
  singleDay,
  halfDay,
  multipleDays;

  String get apiValue => switch (this) {
        LeaveApplyDurationMode.singleDay => 'single_day',
        LeaveApplyDurationMode.halfDay => 'half_day',
        LeaveApplyDurationMode.multipleDays => 'multiple_days',
      };

  String get label => switch (this) {
        LeaveApplyDurationMode.singleDay => 'Single day',
        LeaveApplyDurationMode.halfDay => 'Half day',
        LeaveApplyDurationMode.multipleDays => 'Multiple days',
      };

  static LeaveApplyDurationMode? fromApiValue(String? s) {
    if (s == null) return null;
    switch (s) {
      case 'half_day':
        return LeaveApplyDurationMode.halfDay;
      case 'multiple_days':
        return LeaveApplyDurationMode.multipleDays;
      case 'single_day':
      default:
        return LeaveApplyDurationMode.singleDay;
    }
  }
}

/// Session for a half-day leave.
enum LeaveHalfDayPart {
  firstHalf,
  secondHalf;

  /// API enums are almost always underscored: `first_half` / `second_half` (not spaced words).
  String get apiValue => switch (this) {
        LeaveHalfDayPart.firstHalf => 'first_half',
        LeaveHalfDayPart.secondHalf => 'second_half',
      };

  String get label => switch (this) {
        LeaveHalfDayPart.firstHalf => 'First half',
        LeaveHalfDayPart.secondHalf => 'Second half',
      };

  static LeaveHalfDayPart? fromApiValue(String? s) {
    if (s == null) return null;
    final n = s.trim().toLowerCase();
    if (n == 'second_half' || n == 'second half') {
      return LeaveHalfDayPart.secondHalf;
    }
    if (n == 'first_half' || n == 'first half') {
      return LeaveHalfDayPart.firstHalf;
    }
    return null;
  }
}

/// Configurable leave type from `GET /api/leaves/types`.
class LeaveTypeOption {
  LeaveTypeOption({required this.id, required this.name});

  final String id;
  final String name;

  factory LeaveTypeOption.fromJson(dynamic raw) {
    if (raw is String) {
      return LeaveTypeOption(id: raw, name: raw);
    }
    if (raw is! Map) {
      return LeaveTypeOption(id: '', name: 'Unknown');
    }
    final m = Map<String, dynamic>.from(raw);
    final id = (m['id'] ??
            m['_id'] ??
            m['leaveTypeId'] ??
            m['leave_type_id'] ??
            '')
        .toString();
    final name = (m['name'] ??
            m['label'] ??
            m['title'] ??
            m['type'] ??
            id)
        .toString();
    return LeaveTypeOption(id: id, name: name.isEmpty ? id : name);
  }
}

class ReportingManagerInfo {
  const ReportingManagerInfo({
    required this.isReportingManager,
    required this.teamSize,
  });

  final bool isReportingManager;
  final int teamSize;

  factory ReportingManagerInfo.fromJson(Map<String, dynamic> m) {
    final inner = m['data'] is Map
        ? Map<String, dynamic>.from(m['data'] as Map)
        : m;
    return ReportingManagerInfo(
      isReportingManager:
          inner['isReportingManager'] == true ||
          inner['is_reporting_manager'] == true,
      teamSize: _parseInt(inner['teamSize'] ?? inner['team_size']) ?? 0,
    );
  }
}

int? _parseInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '');
}

/// One leave request row from list or detail APIs.
class LeaveEntry {
  LeaveEntry({
    required this.id,
    this.userId,
    this.userName,
    this.leaveTypeId,
    this.leaveTypeName,
    this.startDate,
    this.endDate,
    this.reason,
    required this.status,
    this.createdAt,
    this.isHalfDay,
    this.durationType,
    this.halfDayPart,
    this.attachmentFileName,
    this.attachmentUrl,
    this.rejectReason,
  });

  final String id;
  final String? userId;
  final String? userName;
  final String? leaveTypeId;
  final String? leaveTypeName;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? reason;
  final String status;
  final DateTime? createdAt;
  final bool? isHalfDay;
  final String? durationType;
  final String? halfDayPart;
  final String? attachmentFileName;
  final String? attachmentUrl;
  final String? rejectReason;

  bool get isPending {
    final s = status.toLowerCase();
    return s == 'pending' || s == 'submitted';
  }

  factory LeaveEntry.fromJson(Map<String, dynamic> raw) {
    final json = _unwrapLeaveJson(raw);
    final typeObj = json['leaveType'] ?? json['leave_type'] ?? json['type'];
    String? typeName;
    String? typeId = (json['leaveTypeId'] ?? json['leave_type_id'])?.toString();
    if (typeObj is Map) {
      final tm = Map<String, dynamic>.from(typeObj);
      typeName = tm['name']?.toString() ?? tm['label']?.toString();
      typeId ??= tm['id']?.toString();
    } else if (typeObj is String) {
      typeName = typeObj;
    }

    final userObj = json['user'] ?? json['employee'] ?? json['applicant'];
    String? userName;
    String? userId = (json['userId'] ?? json['user_id'])?.toString();
    if (userObj is Map) {
      final um = Map<String, dynamic>.from(userObj);
      userName = um['name']?.toString() ??
          um['fullName']?.toString() ??
          um['email']?.toString();
      userId ??= um['id']?.toString() ?? um['_id']?.toString();
    }
    userName ??= json['userName']?.toString() ??
        json['user_name']?.toString() ??
        json['applicantName']?.toString();

    final attachment = json['attachment'];
    String? attachmentFileName = json['attachmentFileName']?.toString() ??
        json['attachment_file_name']?.toString();
    String? attachmentUrl = json['attachmentUrl']?.toString() ??
        json['attachment_url']?.toString();
    if (attachment is Map) {
      final am = Map<String, dynamic>.from(attachment);
      attachmentFileName ??= am['fileName']?.toString() ?? am['name']?.toString();
      attachmentUrl ??= am['url']?.toString() ?? am['path']?.toString();
    }

    return LeaveEntry(
      id: (json['id'] ?? json['_id'])?.toString() ?? '',
      userId: userId,
      userName: userName,
      leaveTypeId: typeId,
      leaveTypeName: typeName ??
          json['leaveTypeName']?.toString() ??
          json['leave_type_name']?.toString(),
      startDate: _parseLeaveDate(
        json['startDate'] ?? json['start_date'] ?? json['from'],
      ),
      endDate: _parseLeaveDate(
        json['endDate'] ?? json['end_date'] ?? json['to'],
      ),
      reason: json['reason']?.toString(),
      status: (json['status'] ?? json['state'] ?? 'pending').toString(),
      createdAt: _parseLeaveDate(
        json['createdAt'] ?? json['created_at'] ?? json['submittedAt'],
      ),
      isHalfDay: json['isHalfDay'] == true ||
          json['is_half_day'] == true ||
          json['halfDay'] == true,
      durationType: json['durationType']?.toString() ??
          json['duration_type']?.toString(),
      halfDayPart: json['halfDayPart']?.toString() ??
          json['half_day_part']?.toString() ??
          json['halfDayPeriod']?.toString() ??
          json['half_day_period']?.toString(),
      attachmentFileName: attachmentFileName,
      attachmentUrl: attachmentUrl,
      rejectReason: json['rejectReason']?.toString() ??
          json['reject_reason']?.toString() ??
          json['rejectionReason']?.toString(),
    );
  }
}

Map<String, dynamic> _unwrapLeaveJson(Map<String, dynamic> raw) {
  final inner = raw['data'] ?? raw['leave'] ?? raw['record'];
  if (inner is Map) {
    return Map<String, dynamic>.from(inner);
  }
  return raw;
}
