import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../models/leave_model.dart';

class LeaveRepository {
  LeaveRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<List<LeaveEntry>> getMyLeaves() async {
    final response = await _api.get(AppConstants.leavesMy);
    return _parseLeaveList(response.data);
  }

  Future<List<LeaveEntry>> getTeamLeaves() async {
    final response = await _api.get(AppConstants.leavesTeam);
    return _parseLeaveList(response.data);
  }

  Future<List<LeaveEntry>> getAllLeaves({
    DateTime? startDate,
    DateTime? endDate,
    String? userIds,
  }) async {
    final qp = <String, dynamic>{};
    if (startDate != null) {
      qp['startDate'] = _dateOnlyIso(startDate);
    }
    if (endDate != null) {
      qp['endDate'] = _dateOnlyIso(endDate);
    }
    if (userIds != null && userIds.trim().isNotEmpty) {
      qp['userIds'] = userIds.trim();
    }
    final response = await _api.get(
      AppConstants.leavesAll,
      queryParameters: qp.isEmpty ? null : qp,
    );
    return _parseLeaveList(response.data);
  }

  Future<ReportingManagerInfo> getReportingManagerInfo() async {
    final response = await _api.get(AppConstants.leavesReportingManager);
    final raw = response.data;
    if (raw is Map<String, dynamic>) {
      return ReportingManagerInfo.fromJson(raw);
    }
    if (raw is Map) {
      return ReportingManagerInfo.fromJson(Map<String, dynamic>.from(raw));
    }
    return const ReportingManagerInfo(isReportingManager: false, teamSize: 0);
  }

  Future<int> calculateWorkingDays({
    required DateTime startDate,
    required DateTime endDate,
    String? userId,
  }) async {
    final response = await _api.post(
      AppConstants.leavesCalculateDays,
      data: {
        'startDate': _dateOnlyIso(startDate),
        'endDate': _dateOnlyIso(endDate),
        if (userId != null && userId.isNotEmpty) 'userId': userId,
      },
    );
    return _parseWorkingDaysCount(response.data);
  }

  Future<List<LeaveTypeOption>> getLeaveTypes() async {
    final response = await _api.get(AppConstants.leavesTypes);
    return _parseTypeList(response.data);
  }

  Future<LeaveEntry> getLeaveById(String leaveId) async {
    final response = await _api.get(AppConstants.leavesById(leaveId));
    final raw = response.data;
    Map<String, dynamic> map;
    if (raw is Map<String, dynamic>) {
      map = raw;
    } else if (raw is Map) {
      map = Map<String, dynamic>.from(raw);
    } else {
      throw Exception('Invalid leave detail response');
    }
    return LeaveEntry.fromJson(map);
  }

  Future<void> applyLeave({
    required String leaveTypeId,
    required DateTime startDate,
    required DateTime endDate,
    String? reason,
    bool isHalfDay = false,
    required String durationType,
    String? halfDayPart,
    String? attachmentFileName,
    String? attachmentData,
  }) async {
    await _api.post(
      AppConstants.leavesApply,
      data: _applyOrUpdateBody(
        leaveTypeId: leaveTypeId,
        startDate: startDate,
        endDate: endDate,
        reason: reason,
        isHalfDay: isHalfDay,
        durationType: durationType,
        halfDayPart: halfDayPart,
        attachmentFileName: attachmentFileName,
        attachmentData: attachmentData,
      ),
    );
  }

  Future<void> updateLeave({
    required String leaveId,
    required String leaveTypeId,
    required DateTime startDate,
    required DateTime endDate,
    String? reason,
    bool isHalfDay = false,
    required String durationType,
    String? halfDayPart,
    String? attachmentFileName,
    String? attachmentData,
  }) async {
    await _api.put(
      AppConstants.leavesById(leaveId),
      data: _applyOrUpdateBody(
        leaveTypeId: leaveTypeId,
        startDate: startDate,
        endDate: endDate,
        reason: reason,
        isHalfDay: isHalfDay,
        durationType: durationType,
        halfDayPart: halfDayPart,
        attachmentFileName: attachmentFileName,
        attachmentData: attachmentData,
      ),
    );
  }

  /// Normalizes half-day session to API enum `first_half` | `second_half` (never spaced words).
  static String _normalizeHalfDayPart(String? raw) {
    if (raw == null || raw.isEmpty) return 'first_half';
    final s = raw.trim().toLowerCase().replaceAll(' ', '_');
    if (s == 'second_half' || s == 'secondhalf') return 'second_half';
    return 'first_half';
  }

  Map<String, dynamic> _applyOrUpdateBody({
    required String leaveTypeId,
    required DateTime startDate,
    required DateTime endDate,
    String? reason,
    required bool isHalfDay,
    required String durationType,
    String? halfDayPart,
    String? attachmentFileName,
    String? attachmentData,
  }) {
    final start = _dateOnlyIso(startDate);
    final end = _dateOnlyIso(endDate);
    final part = isHalfDay ? _normalizeHalfDayPart(halfDayPart) : null;

    return {
      'leaveTypeId': leaveTypeId,
      'leave_type_id': leaveTypeId,
      'startDate': start,
      'start_date': start,
      'endDate': end,
      'end_date': end,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      'isHalfDay': isHalfDay,
      'is_half_day': isHalfDay,
      'durationType': durationType,
      'duration_type': durationType,
      // API expects `halfDayPeriod` (not halfDayPart) — see list/detail response shape.
      if (isHalfDay && part != null) ...{
        'halfDayPeriod': part,
        'half_day_period': part,
      },
      'attachmentFileName': attachmentFileName ?? '',
      'attachment_file_name': attachmentFileName ?? '',
      'attachmentData': attachmentData ?? '',
      'attachment_data': attachmentData ?? '',
    };
  }

  Future<void> approveLeave(String leaveId) async {
    await _api.post(AppConstants.leavesApprove(leaveId));
  }

  Future<void> rejectLeave(String leaveId, String reason) async {
    await _api.post(
      AppConstants.leavesReject(leaveId),
      data: {'reason': reason.trim()},
    );
  }

  Future<List<LeaveTypeOption>> getAllLeaveTypesAdmin() async {
    final response = await _api.get(AppConstants.leavesTypesAll);
    return _parseTypeList(response.data);
  }

  Future<void> createLeaveType(String name) async {
    await _api.post(
      AppConstants.leavesTypes,
      data: {'name': name.trim()},
    );
  }

  Future<void> updateLeaveType(
    String leaveTypeId, {
    String? name,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name.trim();
    if (isActive != null) body['isActive'] = isActive;
    await _api.put(
      AppConstants.leavesTypeById(leaveTypeId),
      data: body,
    );
  }

  Future<void> deleteLeaveType(String leaveTypeId) async {
    await _api.delete(AppConstants.leavesTypeById(leaveTypeId));
  }

  Future<LeaveBalancesResult> getLeaveBalances(String userId) async {
    final response = await _api.get(
      AppConstants.leavesBalances(userId),
      // Avoid any intermediary caching of GET; balances must reflect latest after approve.
      queryParameters: {
        '_': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );
    return LeaveBalancesResult.fromResponse(response.data);
  }

  Future<void> setLeaveBalances(
    String userId,
    List<Map<String, dynamic>> balances,
  ) async {
    await _api.put(
      AppConstants.leavesBalances(userId),
      data: {'balances': balances},
    );
  }

  Future<List<LeaveWeekend>> getWeekends() async {
    final response = await _api.get(AppConstants.leavesWeekends);
    return _parseWeekendList(response.data);
  }

  Future<void> createWeekend(int dayOfWeek) async {
    await _api.post(
      AppConstants.leavesWeekends,
      data: {'dayOfWeek': dayOfWeek},
    );
  }

  Future<void> deleteWeekend(String weekendId) async {
    await _api.delete(AppConstants.leavesWeekendById(weekendId));
  }

  Future<List<LeaveHoliday>> getHolidays() async {
    final response = await _api.get(AppConstants.leavesHolidays);
    return _parseHolidayList(response.data);
  }

  Future<void> createHoliday({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    await _api.post(
      AppConstants.leavesHolidays,
      data: {
        'name': name.trim(),
        'startDate': _dateOnlyIso(startDate),
        'endDate': _dateOnlyIso(endDate),
      },
    );
  }

  Future<void> updateHoliday(
    String holidayId, {
    String? name,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name.trim();
    if (startDate != null) body['startDate'] = _dateOnlyIso(startDate);
    if (endDate != null) body['endDate'] = _dateOnlyIso(endDate);
    await _api.put(AppConstants.leavesHolidayById(holidayId), data: body);
  }

  Future<void> deleteHoliday(String holidayId) async {
    await _api.delete(AppConstants.leavesHolidayById(holidayId));
  }

  static String _dateOnlyIso(DateTime d) {
    final local = d.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static int _parseWorkingDaysCount(dynamic body) {
    if (body is int) return body;
    if (body is num) return body.toInt();
    Map<String, dynamic>? m;
    if (body is Map<String, dynamic>) {
      m = body;
    } else if (body is Map) {
      m = Map<String, dynamic>.from(body);
    }
    if (m == null) return 0;
    final inner = m['data'];
    if (inner is Map) {
      final im = Map<String, dynamic>.from(inner);
      final v = im['workingDays'] ??
          im['working_days'] ??
          im['days'] ??
          im['count'] ??
          im['value'];
      if (v is int) return v;
      if (v is num) return v.toInt();
    }
    final v = m['workingDays'] ??
        m['working_days'] ??
        m['days'] ??
        m['count'] ??
        m['value'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static List<LeaveEntry> _parseLeaveList(dynamic body) {
    final rows = _extractLeaveRowMaps(body);
    return rows
        .map((e) => LeaveEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Handles top-level arrays and common wrappers like `{ data: [...] }`,
  /// `{ data: { leaves: [...] } }`, etc.
  static List<Map<String, dynamic>> _extractLeaveRowMaps(dynamic body) {
    if (body == null) return [];
    if (body is List) {
      return body.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (body is! Map) return [];

    final map = Map<String, dynamic>.from(body);
    for (final key in const [
      'leaves',
      'records',
      'results',
      'items',
      'leaveRequests',
      'requests',
      'myLeaves',
      'list',
    ]) {
      final v = map[key];
      if (v is List) {
        return v
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }

    final data = map['data'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (data is Map) {
      return _extractLeaveRowMaps(data);
    }

    final payload = map['payload'];
    if (payload is List) {
      return payload
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (payload is Map) {
      return _extractLeaveRowMaps(payload);
    }

    return [];
  }

  static List<LeaveTypeOption> _parseTypeList(dynamic raw) {
    List<dynamic> list;
    if (raw is List) {
      list = raw;
    } else if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);
      final inner =
          m['data'] ?? m['types'] ?? m['leaveTypes'] ?? m['leave_types'];
      list = inner is List ? inner : const [];
    } else {
      list = const [];
    }
    return list
        .map(LeaveTypeOption.fromJson)
        .where((t) => t.id.isNotEmpty)
        .toList();
  }

  static List<LeaveWeekend> _parseWeekendList(dynamic body) {
    final rows = _extractMapList(body, const ['weekends', 'data', 'items']);
    return rows
        .map((e) => LeaveWeekend.fromJson(Map<String, dynamic>.from(e)))
        .where((w) => w.id.isNotEmpty)
        .toList();
  }

  static List<LeaveHoliday> _parseHolidayList(dynamic body) {
    final rows = _extractMapList(body, const ['holidays', 'data', 'items']);
    return rows
        .map((e) => LeaveHoliday.fromJson(Map<String, dynamic>.from(e)))
        .where((h) => h.id.isNotEmpty)
        .toList();
  }

  static List<Map<String, dynamic>> _extractMapList(
    dynamic body,
    List<String> arrayKeys,
  ) {
    if (body is List) {
      return body.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (body is! Map) return [];
    final map = Map<String, dynamic>.from(body);
    for (final key in arrayKeys) {
      final v = map[key];
      if (v is List) {
        return v
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    final data = map['data'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (data is Map) {
      return _extractMapList(data, arrayKeys);
    }
    return [];
  }
}

final leaveRepositoryProvider = Provider<LeaveRepository>((ref) {
  return LeaveRepository(apiClient: ref.watch(apiClientProvider));
});
