import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/shift_model.dart';
import '../../data/repositories/shift_repository.dart';

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
      final list = await _repository.getShifts();
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
