import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/shift_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/shift_repository.dart';
import '../../data/repositories/user_repository.dart';

export 'user_profile_shift_provider.dart';

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
      final list = await _repository.getShiftsEnriched();
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
}

final shiftProvider =
    StateNotifierProvider<ShiftNotifier, ShiftState>((ref) {
  return ShiftNotifier(ref.watch(shiftRepositoryProvider));
});

/// One row: [user] plus resolved [shift] (from `User.shiftId` or shift roster).
class UserShiftTiming {
  const UserShiftTiming({required this.user, this.shift});

  final User user;
  final WorkShift? shift;

  /// Human-readable window + shift name (or unassigned).
  String get timingLine => shift?.timingDisplayLine ?? 'No shift assigned';
}

/// Loads all users and matches each to a [WorkShift] using the same rules as attendance
/// (`shiftId` on user, else roster membership on `GET /shifts` enriched with employees),
/// then enriches from `GET /api/hr/info/:userId` when the HR endpoint is allowed (parallel fetch).
final userShiftTimingsProvider =
    FutureProvider<List<UserShiftTiming>>((ref) async {
  final userRepo = ref.read(userRepositoryProvider);
  final shiftRepo = ref.read(shiftRepositoryProvider);
  final users = await userRepo.getUsers(forceRefresh: true);
  final shifts = await shiftRepo.getShiftsEnriched();

  final hrByUserId = <String, Map<String, dynamic>>{};
  await Future.wait(
    users.map((u) async {
      final m = await userRepo.fetchHrInfoByUserId(u.id);
      if (m != null && m.isNotEmpty) hrByUserId[u.id] = m;
    }),
  );

  final rows = users.map((u) {
    WorkShift? shift = WorkShift.byId(u.shiftId, shifts);
    shift ??= WorkShift.forUser(u.id, shifts, userEmail: u.email);
    shift = WorkShift.enrichFromHrInfoPayload(
      shift,
      hrByUserId[u.id],
      shifts,
    );
    return UserShiftTiming(user: u, shift: shift);
  }).toList();
  rows.sort(
    (a, b) => a.user.name.toLowerCase().compareTo(b.user.name.toLowerCase()),
  );
  return rows;
});
