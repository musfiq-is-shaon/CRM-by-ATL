import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/shift_model.dart';
import '../../data/repositories/shift_repository.dart';
import '../../data/repositories/user_repository.dart';
import 'auth_provider.dart';

class ShiftState {
  final List<WorkShift> shifts;
  final bool isLoading;
  final String? error;

  const ShiftState({
    this.shifts = const [],
    this.isLoading = false,
    this.error,
  });

  ShiftState copyWith({
    List<WorkShift>? shifts,
    bool? isLoading,
    Object? error = _sentinel,
  }) {
    return ShiftState(
      shifts: shifts ?? this.shifts,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

const Object _sentinel = Object();

class ShiftNotifier extends StateNotifier<ShiftState> {
  ShiftNotifier(this._repository) : super(const ShiftState());

  final ShiftRepository _repository;

  Future<void> loadShifts() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      var list = await _repository.getShifts();
      list = await _enrichShiftsWithEmployeeRosters(list);
      state = ShiftState(shifts: list, isLoading: false);
    } catch (e) {
      state = ShiftState(
        shifts: state.shifts,
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> createShift(WorkShift draft) async {
    await _repository.createShift(draft);
    await loadShifts();
  }

  Future<void> updateShift(String shiftId, WorkShift draft) async {
    await _repository.updateShift(shiftId, draft);
    await loadShifts();
  }

  Future<void> deleteShift(String shiftId) async {
    await _repository.deleteShift(shiftId);
    await loadShifts();
  }

  Future<void> assignShift({
    required String userId,
    String? shiftId,
  }) async {
    await _repository.assignShift(userId: userId, shiftId: shiftId);
    await loadShifts();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  /// When `GET /shifts` omits `employeeIds`, fetch each shift by id so [WorkShift.forUser]
  /// can resolve assignments for every template (parallel, failures ignored per shift).
  Future<List<WorkShift>> _enrichShiftsWithEmployeeRosters(
    List<WorkShift> list,
  ) async {
    final need = list
        .where((s) => s.id.trim().isNotEmpty && s.employeeIds.isEmpty)
        .toList();
    if (need.isEmpty) return list;
    final details = await Future.wait(
      need.map((s) => _repository.getShiftById(s.id)),
    );
    final byId = <String, WorkShift>{};
    for (var i = 0; i < need.length; i++) {
      final d = details[i];
      if (d != null && d.id.trim().isNotEmpty) {
        byId[d.id.trim().toLowerCase()] = d;
      }
    }
    return list
        .map(
          (s) => WorkShift.mergeRosterFromDetail(
            s,
            byId[s.id.trim().toLowerCase()],
          ),
        )
        .toList();
  }
}

final shiftProvider =
    StateNotifierProvider<ShiftNotifier, ShiftState>((ref) {
  return ShiftNotifier(ref.watch(shiftRepositoryProvider));
});

/// HR-assigned template from [User.shiftId] or `GET /api/users/me` — merged in
/// [WorkShift.resolveAttendanceShift] (no time guessing).
final userProfileShiftProvider = FutureProvider<WorkShift?>((ref) async {
  final user = ref.watch(authProvider.select((a) => a.user));
  final uid = user?.id;
  if (uid == null || uid.isEmpty) return null;
  final shiftRepo = ref.read(shiftRepositoryProvider);
  final userRepo = ref.read(userRepositoryProvider);

  final fromAuth = user?.shiftId?.trim();
  if (fromAuth != null && fromAuth.isNotEmpty) {
    final w = await shiftRepo.getShiftById(fromAuth);
    if (w != null) return w;
  }

  var payload = await userRepo.fetchCurrentUserPayload();
  payload ??= await userRepo.fetchUserPayloadById(uid);
  if (payload == null || payload.isEmpty) return null;
  var w = WorkShift.tryParseFromUserPayload(payload);
  if (w != null && WorkShift.looksPopulated(w)) return w;
  final sid = WorkShift.parseShiftIdFromUserPayload(payload);
  if (sid != null && sid.isNotEmpty) {
    final fetched = await shiftRepo.getShiftById(sid);
    if (fetched != null) return fetched;
  }
  return w;
});
