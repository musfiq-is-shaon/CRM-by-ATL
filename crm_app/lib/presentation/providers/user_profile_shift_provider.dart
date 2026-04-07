import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/attendance_model.dart';
import '../../data/models/shift_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/shift_repository.dart';
import '../../data/repositories/user_repository.dart';
import 'attendance_provider.dart';
import 'auth_provider.dart';

/// When `GET /api/shifts` is empty or omits this template, `GET /api/shifts/:id` often still works for the assigned user.
/// [hrPayload] is `GET /api/hr/info/:userId` — shift id is often only present there.
Future<WorkShift?> _enrichShiftWithDirectTemplateFetch({
  required ShiftRepository shiftRepo,
  required WorkShift? current,
  required User user,
  required TodayAttendance? today,
  required Map<String, dynamic>? payload,
  required Map<String, dynamic>? hrPayload,
}) async {
  if (current != null && WorkShift.looksPopulated(current)) return current;
  final ids = <String?>[
    user.shiftId,
    today?.assignedShiftId,
    if (payload != null) WorkShift.parseShiftIdFromUserPayload(payload),
    if (hrPayload != null) WorkShift.parseShiftIdFromUserPayload(hrPayload),
    if (current != null && current.id.trim().isNotEmpty) current.id,
  ];
  final seen = <String>{};
  WorkShift? acc = current;
  for (final raw in ids) {
    final id = raw?.trim() ?? '';
    if (id.isEmpty) continue;
    final k = id.toLowerCase();
    if (!seen.add(k)) continue;
    final d = await shiftRepo.getShiftById(id);
    if (d == null) continue;
    acc = acc == null ? d : WorkShift.mergeWithSameId(acc, d);
    if (WorkShift.looksPopulated(acc)) return acc;
  }
  return acc;
}

/// Resolves the signed-in user's shift from `/attendance/today`, [User.shiftId], `GET /api/users` payload
/// fallbacks, `GET /api/hr/info/:userId` (when permitted), and `GET /api/shifts` (list only — production API
/// returns **405** on `GET /api/shifts/:id`).
///
/// Kept in a separate library from [attendanceProvider] so nothing in the attendance notifier
/// needs to reference this provider (avoids Riverpod circular dependency when this watches
/// [attendanceProvider]).
final userProfileShiftProvider = FutureProvider<WorkShift?>((ref) async {
  final user = ref.watch(authProvider.select((a) => a.user));
  final uid = user?.id;
  if (user == null || uid == null || uid.isEmpty) return null;

  // Only re-resolve when shift-relevant fields change — not on every [AttendanceState] copy
  // (e.g. tab switches / silent reloads), which used to reset this and flash “Loading shift…”.
  ref.watch(
    attendanceProvider.select(
      (a) {
        final t = a.todayAttendance;
        return Object.hashAll([
          user.shiftId,
          t?.date,
          t?.assignedShiftId,
          t?.shiftStartTime,
          t?.shiftEndTime,
          t?.shiftName,
          t?.hasShiftAssigned,
          t?.checkInTime?.millisecondsSinceEpoch,
        ]);
      },
    ),
  );
  final today = ref.read(attendanceProvider).todayAttendance;

  final shiftRepo = ref.read(shiftRepositoryProvider);
  final userRepo = ref.read(userRepositoryProvider);

  final snap = WorkShift.fromAttendanceDaySnapshot(today);
  if (snap != null &&
      snap.startTime.trim().isNotEmpty &&
      snap.endTime.trim().isNotEmpty) {
    return snap;
  }

  final hrFuture = userRepo.fetchHrInfoByUserId(uid);

  List<WorkShift> shifts;
  try {
    shifts = await shiftRepo.getShiftsEnriched();
  } catch (_) {
    shifts = const [];
  }

  WorkShift? profileFromMe;
  Map<String, dynamic>? payload = await userRepo.fetchCurrentUserPayload();
  payload ??= await userRepo.fetchUserPayloadById(uid);
  final hrPayload = await hrFuture;
  if (payload != null && payload.isNotEmpty) {
    profileFromMe = WorkShift.tryParseFromUserPayload(payload);
    final sid = WorkShift.parseShiftIdFromUserPayload(payload);
    if (profileFromMe != null &&
        !WorkShift.looksPopulated(profileFromMe) &&
        sid != null &&
        sid.isNotEmpty) {
      final fromList = WorkShift.byId(sid, shifts);
      if (fromList != null) {
        profileFromMe = WorkShift.mergeWithSameId(profileFromMe, fromList);
      }
    } else if ((profileFromMe == null ||
            !WorkShift.looksPopulated(profileFromMe)) &&
        sid != null &&
        sid.isNotEmpty) {
      profileFromMe = WorkShift.byId(sid, shifts);
    }
  }

  profileFromMe = WorkShift.enrichFromHrInfoPayload(
    profileFromMe,
    hrPayload,
    shifts,
  );

  final prefetched = WorkShift.byId(today?.assignedShiftId, shifts) ??
      WorkShift.byId(user.shiftId, shifts);

  final resolved = WorkShift.resolveAttendanceShift(
    shifts: shifts,
    assignedShiftIdFromToday: today?.assignedShiftId,
    shiftIdFromAuthUser: user.shiftId,
    userId: uid,
    userEmail: user.email,
    profileShift: profileFromMe,
    prefetchedByTemplateId: prefetched,
  );
  if (resolved != null) {
    return _enrichShiftWithDirectTemplateFetch(
      shiftRepo: shiftRepo,
      current: resolved,
      user: user,
      today: today,
      payload: payload,
      hrPayload: hrPayload,
    );
  }

  for (final raw in <String?>[
    today?.assignedShiftId,
    user.shiftId,
    if (payload != null) WorkShift.parseShiftIdFromUserPayload(payload),
  ]) {
    final w = WorkShift.byId(raw, shifts);
    if (w != null) {
      return _enrichShiftWithDirectTemplateFetch(
        shiftRepo: shiftRepo,
        current: w,
        user: user,
        today: today,
        payload: payload,
        hrPayload: hrPayload,
      );
    }
  }

  // Backend often sets hasShiftAssigned on GET /attendance/today but omits shift id / times; GET /shifts/:id
  // is not available (405). Show a clear placeholder when the server confirms assignment.
  final t = today;
  if (t != null && t.hasShiftAssigned == true) {
    final id = t.assignedShiftId?.trim() ?? '';
    final st = t.shiftStartTime?.trim() ?? '';
    final et = t.shiftEndTime?.trim() ?? '';
    final nm = t.shiftName?.trim() ?? '';
    return _enrichShiftWithDirectTemplateFetch(
      shiftRepo: shiftRepo,
      current: WorkShift(
        id: id,
        name: nm.isNotEmpty ? nm : 'Shift assigned',
        startTime: st,
        endTime: et,
        weekendDays: const [],
        gracePeriod: t.shiftGraceMinutes ?? 0,
        employeeIds: const [],
      ),
      user: user,
      today: today,
      payload: payload,
      hrPayload: hrPayload,
    );
  }

  return _enrichShiftWithDirectTemplateFetch(
    shiftRepo: shiftRepo,
    current: null,
    user: user,
    today: today,
    payload: payload,
    hrPayload: hrPayload,
  );
});
