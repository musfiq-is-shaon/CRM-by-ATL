import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/async_load_helper.dart';
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
    this.refreshingTypes = false,
    this.refreshingWeekends = false,
    this.refreshingHolidays = false,
    this.error,
  });

  final List<LeaveTypeOption> types;
  final List<LeaveWeekend> weekends;
  final List<LeaveHoliday> holidays;
  final bool loadingTypes;
  final bool loadingWeekends;
  final bool loadingHolidays;
  final bool refreshingTypes;
  final bool refreshingWeekends;
  final bool refreshingHolidays;
  final String? error;

  LeaveHrAdminState copyWith({
    List<LeaveTypeOption>? types,
    List<LeaveWeekend>? weekends,
    List<LeaveHoliday>? holidays,
    bool? loadingTypes,
    bool? loadingWeekends,
    bool? loadingHolidays,
    bool? refreshingTypes,
    bool? refreshingWeekends,
    bool? refreshingHolidays,
    Object? error = _sentinel,
  }) {
    return LeaveHrAdminState(
      types: types ?? this.types,
      weekends: weekends ?? this.weekends,
      holidays: holidays ?? this.holidays,
      loadingTypes: loadingTypes ?? this.loadingTypes,
      loadingWeekends: loadingWeekends ?? this.loadingWeekends,
      loadingHolidays: loadingHolidays ?? this.loadingHolidays,
      refreshingTypes: refreshingTypes ?? this.refreshingTypes,
      refreshingWeekends: refreshingWeekends ?? this.refreshingWeekends,
      refreshingHolidays: refreshingHolidays ?? this.refreshingHolidays,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

const Object _sentinel = Object();

class LeaveHrAdminNotifier extends StateNotifier<LeaveHrAdminState> {
  LeaveHrAdminNotifier(this._repository) : super(const LeaveHrAdminState());

  final LeaveRepository _repository;

  Future<void> loadTypes({bool refresh = false}) async {
    final hadCache = state.types.isNotEmpty;
    if (!hadCache) {
      state = state.copyWith(
        loadingTypes: true,
        refreshingTypes: false,
        error: null,
      );
    } else if (refresh) {
      state = state.copyWith(refreshingTypes: true, error: null);
    } else {
      final flags = beginAsyncLoad(hasCachedData: true);
      state = state.copyWith(
        loadingTypes: flags.isLoading,
        refreshingTypes: flags.isRefreshing,
        error: null,
      );
    }
    try {
      final list = await _repository.getAllLeaveTypesAdmin();
      state = state.copyWith(
        types: list,
        loadingTypes: false,
        refreshingTypes: false,
      );
    } catch (e) {
      state = state.copyWith(
        loadingTypes: false,
        refreshingTypes: false,
        error: asyncLoadError(e).replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> loadWeekends({bool refresh = false}) async {
    final hadCache = state.weekends.isNotEmpty;
    if (!hadCache) {
      state = state.copyWith(
        loadingWeekends: true,
        refreshingWeekends: false,
        error: null,
      );
    } else if (refresh) {
      state = state.copyWith(refreshingWeekends: true, error: null);
    } else {
      final flags = beginAsyncLoad(hasCachedData: true);
      state = state.copyWith(
        loadingWeekends: flags.isLoading,
        refreshingWeekends: flags.isRefreshing,
        error: null,
      );
    }
    try {
      final list = await _repository.getWeekends();
      state = state.copyWith(
        weekends: list,
        loadingWeekends: false,
        refreshingWeekends: false,
      );
    } catch (e) {
      state = state.copyWith(
        loadingWeekends: false,
        refreshingWeekends: false,
        error: asyncLoadError(e).replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> loadHolidays({bool refresh = false}) async {
    final hadCache = state.holidays.isNotEmpty;
    if (!hadCache) {
      state = state.copyWith(
        loadingHolidays: true,
        refreshingHolidays: false,
        error: null,
      );
    } else if (refresh) {
      state = state.copyWith(refreshingHolidays: true, error: null);
    } else {
      final flags = beginAsyncLoad(hasCachedData: true);
      state = state.copyWith(
        loadingHolidays: flags.isLoading,
        refreshingHolidays: flags.isRefreshing,
        error: null,
      );
    }
    try {
      final list = await _repository.getHolidays();
      state = state.copyWith(
        holidays: list,
        loadingHolidays: false,
        refreshingHolidays: false,
      );
    } catch (e) {
      state = state.copyWith(
        loadingHolidays: false,
        refreshingHolidays: false,
        error: asyncLoadError(e).replaceFirst('Exception: ', ''),
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
