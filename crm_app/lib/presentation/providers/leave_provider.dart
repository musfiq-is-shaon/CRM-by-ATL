import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/leave_model.dart';
import '../../data/repositories/leave_repository.dart';
import 'auth_provider.dart';

enum LeaveListScope { mine, team, all }

class LeaveState {
  final List<LeaveEntry> leaves;
  final List<LeaveTypeOption> types;
  final bool isLoading;
  final bool typesLoading;
  final String? error;
  final LeaveListScope scope;
  final ReportingManagerInfo? reportingInfo;
  final bool reportingLoaded;

  const LeaveState({
    this.leaves = const [],
    this.types = const [],
    this.isLoading = false,
    this.typesLoading = false,
    this.error,
    this.scope = LeaveListScope.mine,
    this.reportingInfo,
    this.reportingLoaded = false,
  });

  LeaveState copyWith({
    List<LeaveEntry>? leaves,
    List<LeaveTypeOption>? types,
    bool? isLoading,
    bool? typesLoading,
    Object? error = _sentinel,
    LeaveListScope? scope,
    ReportingManagerInfo? reportingInfo,
    bool? reportingLoaded,
  }) {
    return LeaveState(
      leaves: leaves ?? this.leaves,
      types: types ?? this.types,
      isLoading: isLoading ?? this.isLoading,
      typesLoading: typesLoading ?? this.typesLoading,
      error: identical(error, _sentinel) ? this.error : error as String?,
      scope: scope ?? this.scope,
      reportingInfo: reportingInfo ?? this.reportingInfo,
      reportingLoaded: reportingLoaded ?? this.reportingLoaded,
    );
  }
}

const Object _sentinel = Object();

class LeaveNotifier extends StateNotifier<LeaveState> {
  LeaveNotifier(this._repository, this.ref) : super(const LeaveState());

  final LeaveRepository _repository;
  final Ref ref;

  Future<void> loadReportingInfo() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    try {
      final info = await _repository.getReportingManagerInfo();
      state = state.copyWith(reportingInfo: info, reportingLoaded: true);
    } catch (_) {
      state = state.copyWith(
        reportingInfo: const ReportingManagerInfo(
          isReportingManager: false,
          teamSize: 0,
        ),
        reportingLoaded: true,
      );
    }
  }

  Future<void> loadLeaves() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      state = state.copyWith(isLoading: false, error: 'User not authenticated');
      return;
    }
    state = state.copyWith(isLoading: true, error: null);
    try {
      final isAdmin = ref.read(isAdminProvider);
      final scope = state.scope;
      if (scope == LeaveListScope.all && !isAdmin) {
        state = state.copyWith(
          isLoading: false,
          error: 'Only admins can view all leave requests',
        );
        return;
      }
      if (scope == LeaveListScope.team) {
        final isMgr = state.reportingInfo?.isReportingManager ?? false;
        if (!isMgr && !isAdmin) {
          state = state.copyWith(
            isLoading: false,
            error: 'You are not a reporting manager for any team',
          );
          return;
        }
      }

      final list = switch (scope) {
        LeaveListScope.mine => await _repository.getMyLeaves(),
        LeaveListScope.team => await _repository.getTeamLeaves(),
        LeaveListScope.all => await _repository.getAllLeaves(),
      };
      state = state.copyWith(leaves: list, isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void setScope(LeaveListScope scope) {
    if (state.scope == scope) return;
    state = state.copyWith(scope: scope);
    loadLeaves();
  }

  /// Ensures [reportingInfo] is loaded before [loadLeaves] when using team scope.
  Future<void> bootstrapList() async {
    await loadReportingInfo();
    await loadLeaves();
  }

  Future<void> loadTypes() async {
    state = state.copyWith(typesLoading: true);
    try {
      final types = await _repository.getLeaveTypes();
      state = state.copyWith(types: types, typesLoading: false);
    } catch (_) {
      state = state.copyWith(typesLoading: false);
    }
  }

  Future<int> calculateWorkingDays({
    required DateTime startDate,
    required DateTime endDate,
    String? userId,
  }) {
    return _repository.calculateWorkingDays(
      startDate: startDate,
      endDate: endDate,
      userId: userId,
    );
  }

  Future<void> applyLeave({
    required String leaveTypeId,
    required DateTime startDate,
    required DateTime endDate,
    String? reason,
    required LeaveApplyDurationMode durationMode,
    LeaveHalfDayPart? halfDayPart,
    String? attachmentFileName,
    String? attachmentData,
  }) async {
    final isHalf = durationMode == LeaveApplyDurationMode.halfDay;
    await _repository.applyLeave(
      leaveTypeId: leaveTypeId,
      startDate: startDate,
      endDate: endDate,
      reason: reason,
      isHalfDay: isHalf,
      durationType: durationMode.apiValue,
      halfDayPart: isHalf
          ? (halfDayPart?.apiValue ?? LeaveHalfDayPart.firstHalf.apiValue)
          : null,
      attachmentFileName: attachmentFileName,
      attachmentData: attachmentData,
    );
    await loadLeaves();
  }

  Future<void> updateLeave({
    required String leaveId,
    required String leaveTypeId,
    required DateTime startDate,
    required DateTime endDate,
    String? reason,
    required LeaveApplyDurationMode durationMode,
    LeaveHalfDayPart? halfDayPart,
    String? attachmentFileName,
    String? attachmentData,
  }) async {
    final isHalf = durationMode == LeaveApplyDurationMode.halfDay;
    await _repository.updateLeave(
      leaveId: leaveId,
      leaveTypeId: leaveTypeId,
      startDate: startDate,
      endDate: endDate,
      reason: reason,
      isHalfDay: isHalf,
      durationType: durationMode.apiValue,
      halfDayPart: isHalf
          ? (halfDayPart?.apiValue ?? LeaveHalfDayPart.firstHalf.apiValue)
          : null,
      attachmentFileName: attachmentFileName,
      attachmentData: attachmentData,
    );
    await loadLeaves();
  }

  Future<void> approveLeave(String leaveId) async {
    await _repository.approveLeave(leaveId);
    await loadLeaves();
  }

  Future<void> rejectLeave(String leaveId, String reason) async {
    await _repository.rejectLeave(leaveId, reason);
    await loadLeaves();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final leaveProvider =
    StateNotifierProvider<LeaveNotifier, LeaveState>((ref) {
  return LeaveNotifier(ref.watch(leaveRepositoryProvider), ref);
});
