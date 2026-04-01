import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/leave_model.dart';
import '../../data/repositories/leave_repository.dart';

class LeaveHrAdminState {
  const LeaveHrAdminState({
    this.types = const [],
    this.weekends = const [],
    this.holidays = const [],
    this.loadingTypes = false,
    this.loadingWeekends = false,
    this.loadingHolidays = false,
    this.error,
  });

  final List<LeaveTypeOption> types;
  final List<LeaveWeekend> weekends;
  final List<LeaveHoliday> holidays;
  final bool loadingTypes;
  final bool loadingWeekends;
  final bool loadingHolidays;
  final String? error;

  LeaveHrAdminState copyWith({
    List<LeaveTypeOption>? types,
    List<LeaveWeekend>? weekends,
    List<LeaveHoliday>? holidays,
    bool? loadingTypes,
    bool? loadingWeekends,
    bool? loadingHolidays,
    Object? error = _sentinel,
  }) {
    return LeaveHrAdminState(
      types: types ?? this.types,
      weekends: weekends ?? this.weekends,
      holidays: holidays ?? this.holidays,
      loadingTypes: loadingTypes ?? this.loadingTypes,
      loadingWeekends: loadingWeekends ?? this.loadingWeekends,
      loadingHolidays: loadingHolidays ?? this.loadingHolidays,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

const Object _sentinel = Object();

class LeaveHrAdminNotifier extends StateNotifier<LeaveHrAdminState> {
  LeaveHrAdminNotifier(this._repository) : super(const LeaveHrAdminState());

  final LeaveRepository _repository;

  Future<void> loadTypes() async {
    state = state.copyWith(loadingTypes: true, error: null);
    try {
      final list = await _repository.getAllLeaveTypesAdmin();
      state = state.copyWith(types: list, loadingTypes: false);
    } catch (e) {
      state = state.copyWith(
        loadingTypes: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> loadWeekends() async {
    state = state.copyWith(loadingWeekends: true, error: null);
    try {
      final list = await _repository.getWeekends();
      state = state.copyWith(weekends: list, loadingWeekends: false);
    } catch (e) {
      state = state.copyWith(
        loadingWeekends: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> loadHolidays() async {
    state = state.copyWith(loadingHolidays: true, error: null);
    try {
      final list = await _repository.getHolidays();
      state = state.copyWith(holidays: list, loadingHolidays: false);
    } catch (e) {
      state = state.copyWith(
        loadingHolidays: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  Future<void> createLeaveType(String name) async {
    await _repository.createLeaveType(name);
    await loadTypes();
  }

  Future<void> updateLeaveType(
    String id, {
    String? name,
    bool? isActive,
  }) async {
    await _repository.updateLeaveType(id, name: name, isActive: isActive);
    await loadTypes();
  }

  Future<void> deleteLeaveType(String id) async {
    await _repository.deleteLeaveType(id);
    await loadTypes();
  }

  Future<void> createWeekend(int dayOfWeek) async {
    await _repository.createWeekend(dayOfWeek);
    await loadWeekends();
  }

  Future<void> deleteWeekend(String id) async {
    await _repository.deleteWeekend(id);
    await loadWeekends();
  }

  Future<void> createHoliday({
    required String name,
    required DateTime start,
    required DateTime end,
  }) async {
    await _repository.createHoliday(
      name: name,
      startDate: start,
      endDate: end,
    );
    await loadHolidays();
  }

  Future<void> updateHoliday(
    String id, {
    String? name,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    await _repository.updateHoliday(
      id,
      name: name,
      startDate: startDate,
      endDate: endDate,
    );
    await loadHolidays();
  }

  Future<void> deleteHoliday(String id) async {
    await _repository.deleteHoliday(id);
    await loadHolidays();
  }
}

final leaveHrAdminProvider =
    StateNotifierProvider<LeaveHrAdminNotifier, LeaveHrAdminState>((ref) {
  return LeaveHrAdminNotifier(ref.watch(leaveRepositoryProvider));
});
