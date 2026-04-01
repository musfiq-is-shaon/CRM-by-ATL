import '../../core/json_parse.dart';

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

  /// Backend / Postman: `multiple_day` (singular).
  String get apiValue => switch (this) {
    LeaveApplyDurationMode.singleDay => 'single_day',
    LeaveApplyDurationMode.halfDay => 'half_day',
    LeaveApplyDurationMode.multipleDays => 'multiple_day',
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
      case 'multiple_day':
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

/// Configurable leave type from `GET /api/leaves/types` (and admin `/types/all`).
class LeaveTypeOption {
  LeaveTypeOption({required this.id, required this.name, this.isActive});

  final String id;
  final String name;
  final bool? isActive;

  factory LeaveTypeOption.fromJson(dynamic raw) {
    if (raw is String) {
      return LeaveTypeOption(id: raw, name: raw);
    }
    if (raw is! Map) {
      return LeaveTypeOption(id: '', name: 'Unknown');
    }
    final m = Map<String, dynamic>.from(raw);
    final id =
        (m['id'] ?? m['_id'] ?? m['leaveTypeId'] ?? m['leave_type_id'] ?? '')
            .toString();
    final name = (m['name'] ?? m['label'] ?? m['title'] ?? m['type'] ?? id)
        .toString();
    return LeaveTypeOption(
      id: id,
      name: name.isEmpty ? id : name,
      isActive: parseOptionalBool(m['isActive'] ?? m['is_active']),
    );
  }
}

/// One row from `GET /api/leaves/balances/:userId`.
class LeaveBalanceRow {
  LeaveBalanceRow({
    required this.leaveTypeId,
    this.leaveTypeName,
    this.isActive,
    this.creditedDays,
    this.remainingDays,
    this.additionalOutstandingDays,
    required this.balance,
  });

  final String leaveTypeId;
  final String? leaveTypeName;
  final bool? isActive;
  final double? creditedDays;
  final double? remainingDays;
  final double? additionalOutstandingDays;
  final double balance;

  factory LeaveBalanceRow.fromJson(Map<String, dynamic> m) {
    String leaveTypeId = (m['leaveTypeId'] ?? m['leave_type_id'] ?? '')
        .toString();
    String? leaveTypeName =
        m['leaveTypeName']?.toString() ?? m['leave_type_name']?.toString();

    final lt = m['leaveType'] ?? m['leave_type'];
    if (lt is Map) {
      final lm = Map<String, dynamic>.from(lt);
      if (leaveTypeId.isEmpty) {
        leaveTypeId = (lm['id'] ?? lm['_id'] ?? '').toString();
      }
      leaveTypeName ??= lm['name']?.toString() ?? lm['label']?.toString();
    }

    final sources = <Map<String, dynamic>>[
      m,
      if (lt is Map) Map<String, dynamic>.from(lt),
      if (m['stats'] is Map) Map<String, dynamic>.from(m['stats'] as Map),
      if (m['summary'] is Map) Map<String, dynamic>.from(m['summary'] as Map),
      if (m['totals'] is Map) Map<String, dynamic>.from(m['totals'] as Map),
      if (m['meta'] is Map) Map<String, dynamic>.from(m['meta'] as Map),
    ];
    dynamic pick(List<String> keys) {
      for (final src in sources) {
        for (final k in keys) {
          final v = src[k];
          if (v != null && v.toString().trim().isNotEmpty) return v;
        }
      }
      return null;
    }

    /// Explicit remaining at **row root** only (never `balance` — that is allocated).
    double? parseRootRemaining() {
      for (final k in const [
        'remainingBalance',
        'remaining_balance',
        'remaining',
        'remainingDays',
        'remaining_days',
        'availableDays',
        'available_days',
        'available',
        'leftDays',
        'left_days',
        'left',
      ]) {
        final v = m[k];
        if (v != null && v.toString().trim().isNotEmpty) {
          return parseOptionalNum(v)?.toDouble();
        }
      }
      return null;
    }

    final rootAllocated = parseOptionalNum(
      m['balance'] ?? m['allocated'] ?? m['allocatedDays'],
    )?.toDouble();

    // API docs: `balance` on each row is **allocated** (pool), not remaining.
    final creditedRaw = pick([
      'creditedDays',
      'credited_days',
      'credited',
      'credit',
      'creditedLeave',
      'credited_leave',
      'allocatedDays',
      'allocated_days',
      'allocated',
      'allocation',
      'entitledDays',
      'entitled_days',
      'entitlement',
      'totalAllocated',
      'total_allocated',
      'totalDays',
      'total_days',
      'balance',
    ]);
    // Do not use `balance` here — same key as allocated pool per API.
    // Do not include ambiguous `days` — often means annual entitlement in nested maps.
    final remainingRaw = pick([
      'remainingBalance',
      'remaining_balance',
      'remainingDays',
      'remaining_days',
      'remaining',
      'availableDays',
      'available_days',
      'available',
      'leftDays',
      'left_days',
      'left',
    ]);
    final usedRaw = pick([
      'usedDays',
      'used_days',
      'used',
      'consumedDays',
      'consumed_days',
      'consumed',
      'takenDays',
      'taken_days',
      'taken',
      'availedDays',
      'availed_days',
      'availed',
    ]);
    final additionalOutstandingRaw = pick([
      'additionalOutstanding',
      'additional_outstanding',
      'additionalOutstandingDays',
      'additional_outstanding_days',
    ]);
    final rootRemaining = parseRootRemaining();

    bool? active = parseOptionalBool(m['isActive'] ?? m['is_active']);
    if (active == null && lt is Map) {
      final lm = Map<String, dynamic>.from(lt);
      active = parseOptionalBool(lm['isActive'] ?? lm['is_active']);
    }

    double? credited = parseOptionalNum(creditedRaw)?.toDouble();
    final used = parseOptionalNum(usedRaw)?.toDouble();
    final usedNum = used ?? 0.0;

    double? remaining = rootRemaining;
    remaining ??= parseOptionalNum(remainingRaw)?.toDouble();

    // Derive missing values when API omits one side.
    if (credited == null && remaining != null && used != null) {
      credited = remaining + used;
    }
    // `balance` in API = allocated pool; remaining = pool − used.
    credited ??= rootAllocated;
    if (remaining == null && credited != null) {
      remaining = credited - usedNum;
    }

    // `balance` on the API row is allocated pool (PUT body); keep that for HR screens.
    final allocated = rootAllocated ?? credited ?? 0.0;
    final additionalOutstanding = parseOptionalNum(additionalOutstandingRaw)
        ?.toDouble();

    return LeaveBalanceRow(
      leaveTypeId: leaveTypeId,
      leaveTypeName: leaveTypeName,
      isActive: active,
      creditedDays: credited,
      remainingDays: remaining,
      additionalOutstandingDays: additionalOutstanding,
      balance: allocated,
    );
  }

  static List<LeaveBalanceRow> listFromDynamic(dynamic raw) {
    if (raw is! List) return [];
    final out = <LeaveBalanceRow>[];
    for (final e in raw) {
      if (e is! Map) continue;
      try {
        out.add(LeaveBalanceRow.fromJson(Map<String, dynamic>.from(e)));
      } catch (_) {
        // Malformed row; skip so the rest of the UI still loads.
      }
    }
    return out;
  }
}

class LeaveBalancesResult {
  LeaveBalancesResult({required this.userId, required this.balances});

  final String userId;
  final List<LeaveBalanceRow> balances;

  factory LeaveBalancesResult.fromJson(Map<String, dynamic> map) {
    final inner = map['data'] is Map
        ? Map<String, dynamic>.from(map['data'] as Map)
        : map;
    final uid =
        (inner['userId'] ??
                inner['user_id'] ??
                map['userId'] ??
                map['user_id'] ??
                '')
            .toString();
    final rawBalances = inner['balances'] ?? inner['rows'] ?? inner['items'];
    final rawList = rawBalances is List
        ? rawBalances
        : (inner['data'] is List ? inner['data'] as List<dynamic> : null);
    final list = rawList != null
        ? LeaveBalanceRow.listFromDynamic(rawList)
        : <LeaveBalanceRow>[];
    return LeaveBalancesResult(userId: uid, balances: list);
  }

  /// Accepts a JSON object or a bare array of balance rows.
  factory LeaveBalancesResult.fromResponse(dynamic raw) {
    if (raw == null) {
      return LeaveBalancesResult(userId: '', balances: []);
    }
    if (raw is List) {
      return LeaveBalancesResult(
        userId: '',
        balances: LeaveBalanceRow.listFromDynamic(raw),
      );
    }
    if (raw is Map<String, dynamic>) {
      return LeaveBalancesResult.fromJson(raw);
    }
    if (raw is Map) {
      return LeaveBalancesResult.fromJson(Map<String, dynamic>.from(raw));
    }
    return LeaveBalancesResult(userId: '', balances: []);
  }
}

/// Global weekend day from `GET /api/leaves/weekends`.
class LeaveWeekend {
  LeaveWeekend({required this.id, required this.dayOfWeek});

  final String id;
  final int dayOfWeek;

  factory LeaveWeekend.fromJson(Map<String, dynamic> m) {
    final id = (m['id'] ?? m['_id'] ?? '').toString();
    final dow = m['dayOfWeek'] ?? m['day_of_week'];
    return LeaveWeekend(
      id: id,
      dayOfWeek: dow is int ? dow : int.tryParse(dow?.toString() ?? '') ?? 0,
    );
  }

  static String weekdayLabel(int d) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (d < 0 || d > 6) return 'Day $d';
    return names[d];
  }
}

/// Holiday from `GET /api/leaves/holidays`.
class LeaveHoliday {
  LeaveHoliday({
    required this.id,
    required this.name,
    this.startDate,
    this.endDate,
  });

  final String id;
  final String name;
  final DateTime? startDate;
  final DateTime? endDate;

  factory LeaveHoliday.fromJson(Map<String, dynamic> m) {
    final id = (m['id'] ?? m['_id'] ?? '').toString();
    final name = (m['name'] ?? m['title'] ?? 'Holiday').toString();
    return LeaveHoliday(
      id: id,
      name: name,
      startDate: _parseLeaveDate(
        m['startDate'] ?? m['start_date'] ?? m['date'],
      ),
      endDate: _parseLeaveDate(m['endDate'] ?? m['end_date'] ?? m['date']),
    );
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
          parseOptionalBool(
            inner['isReportingManager'] ?? inner['is_reporting_manager'],
          ) ??
          false,
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
    this.userEmail,
    this.userPhone,
    this.leaveTypeId,
    this.leaveTypeName,
    this.startDate,
    this.endDate,
    this.reason,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.approvedAt,
    this.rejectedAt,
    this.isHalfDay,
    this.durationType,
    this.halfDayPart,
    this.attachmentFileName,
    this.attachmentUrl,
    this.rejectReason,
    this.additionalLeaveDays,
    this.totalDays,
    this.workingDays,
    this.approvedByName,
    this.rejectedByName,
  });

  final String id;
  final String? userId;
  final String? userName;
  final String? userEmail;
  final String? userPhone;
  final String? leaveTypeId;
  final String? leaveTypeName;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? reason;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final bool? isHalfDay;
  final String? durationType;
  final String? halfDayPart;
  final String? attachmentFileName;
  final String? attachmentUrl;
  final String? rejectReason;
  final num? additionalLeaveDays;
  final num? totalDays;
  final num? workingDays;
  final String? approvedByName;
  final String? rejectedByName;

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
    String? userEmail;
    String? userPhone;
    String? userId = (json['userId'] ?? json['user_id'])?.toString();
    if (userObj is Map) {
      final um = Map<String, dynamic>.from(userObj);
      userName =
          um['name']?.toString() ??
          um['fullName']?.toString() ??
          um['full_name']?.toString();
      userEmail = um['email']?.toString();
      userPhone =
          um['phone']?.toString() ??
          um['phoneNumber']?.toString() ??
          um['phone_number']?.toString() ??
          um['mobile']?.toString();
      userId ??= um['id']?.toString() ?? um['_id']?.toString();
    }
    userName ??=
        json['userName']?.toString() ??
        json['user_name']?.toString() ??
        json['applicantName']?.toString();
    userEmail ??=
        json['userEmail']?.toString() ?? json['user_email']?.toString();
    userPhone ??=
        json['userPhone']?.toString() ?? json['user_phone']?.toString();

    String? approvedByName;
    final ap =
        json['approvedBy'] ??
        json['approver'] ??
        json['reviewedBy'] ??
        json['approved_by'];
    if (ap is Map) {
      final am = Map<String, dynamic>.from(ap);
      approvedByName =
          am['name']?.toString() ??
          am['fullName']?.toString() ??
          am['email']?.toString();
    } else if (ap is String && ap.trim().isNotEmpty) {
      approvedByName = ap.trim();
    }
    approvedByName ??=
        json['approvedByName']?.toString() ??
        json['approved_by_name']?.toString() ??
        json['approverName']?.toString();

    String? rejectedByName;
    final rp = json['rejectedBy'] ?? json['rejected_by'];
    if (rp is Map) {
      final rm = Map<String, dynamic>.from(rp);
      rejectedByName =
          rm['name']?.toString() ??
          rm['fullName']?.toString() ??
          rm['email']?.toString();
    } else if (rp is String && rp.trim().isNotEmpty) {
      rejectedByName = rp.trim();
    }
    rejectedByName ??=
        json['rejectedByName']?.toString() ??
        json['rejected_by_name']?.toString();

    final attachment = json['attachment'];
    String? attachmentFileName =
        json['attachmentFileName']?.toString() ??
        json['attachment_file_name']?.toString();
    String? attachmentUrl =
        json['attachmentUrl']?.toString() ?? json['attachment_url']?.toString();
    if (attachment is Map) {
      final am = Map<String, dynamic>.from(attachment);
      attachmentFileName ??=
          am['fileName']?.toString() ?? am['name']?.toString();
      attachmentUrl ??= am['url']?.toString() ?? am['path']?.toString();
    }

    return LeaveEntry(
      id: (json['id'] ?? json['_id'])?.toString() ?? '',
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      userPhone: userPhone,
      leaveTypeId: typeId,
      leaveTypeName:
          typeName ??
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
        json['createdAt'] ??
            json['created_at'] ??
            json['submittedAt'] ??
            json['submitted_at'],
      ),
      updatedAt: _parseLeaveDate(
        json['updatedAt'] ??
            json['updated_at'] ??
            json['modifiedAt'] ??
            json['modified_at'] ??
            json['lastModified'],
      ),
      approvedAt: _parseLeaveDate(
        json['approvedAt'] ?? json['approved_at'] ?? json['decisionAt'],
      ),
      rejectedAt: _parseLeaveDate(json['rejectedAt'] ?? json['rejected_at']),
      isHalfDay:
          parseOptionalBool(
            json['isHalfDay'] ?? json['is_half_day'] ?? json['halfDay'],
          ) ??
          false,
      durationType:
          json['durationType']?.toString() ?? json['duration_type']?.toString(),
      halfDayPart:
          json['halfDayPart']?.toString() ??
          json['half_day_part']?.toString() ??
          json['halfDayPeriod']?.toString() ??
          json['half_day_period']?.toString(),
      attachmentFileName: attachmentFileName,
      attachmentUrl: attachmentUrl,
      rejectReason:
          json['rejectReason']?.toString() ??
          json['reject_reason']?.toString() ??
          json['rejectionReason']?.toString(),
      additionalLeaveDays: parseOptionalNum(
        json['additionalLeaveDays'] ?? json['additional_leave_days'],
      ),
      totalDays: parseOptionalNum(
        json['totalDays'] ??
            json['total_days'] ??
            json['dayCount'] ??
            json['day_count'] ??
            json['numberOfDays'] ??
            json['days'],
      ),
      workingDays: parseOptionalNum(
        json['workingDays'] ??
            json['working_days'] ??
            json['businessDays'] ??
            json['business_days'],
      ),
      approvedByName: approvedByName,
      rejectedByName: rejectedByName,
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
