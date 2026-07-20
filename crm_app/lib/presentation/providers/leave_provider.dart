import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/async_load_helper.dart';
import '../../data/models/leave_model.dart';
import '../../data/repositories/leave_repository.dart';
import 'auth_provider.dart';
import 'rbac_provider.dart';

/// GET `/api/leaves/my` for dashboard attendance + shift check-in reminder filtering.
final myLeavesForAttendanceProvider =
    FutureProvider<List<LeaveEntry>>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null || uid.isEmpty) return const [];
  return ref.read(leaveRepositoryProvider).getMyLeaves();
});

enum LeaveListScope { mine, team, all }

/// Optional filters for `GET /api/leaves/all` (admin).
class LeaveAdminAllFilters {
  const LeaveAdminAllFilters({
    this.startDate,
    this.endDate,
    this.userIds = '',
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final String userIds;
}

class LeaveState {
  final List<LeaveEntry> leaves;
  final List<LeaveTypeOption> types;
  final bool isLoading;
  final bool isRefreshing;
  final bool typesLoading;
  final String? error;
  final LeaveListScope scope;
  final ReportingManagerInfo? reportingInfo;
  final bool reportingLoaded;
  final LeaveAdminAllFilters adminAllFilters;
  /// Current user's allocated balances (`GET /api/leaves/balances/:userId`).
  final List<LeaveBalanceRow> myBalances;
  final bool balancesLoading;
  final String? balancesError;

  const LeaveState({
    this.leaves = const [],
    this.types = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.typesLoading = false,
    this.error,
    this.scope = LeaveListScope.mine,
    this.reportingInfo,
    this.reportingLoaded = false,
    this.adminAllFilters = const LeaveAdminAllFilters(),
    this.myBalances = const [],
    this.balancesLoading = false,
    this.balancesError,
  });

  LeaveState copyWith({
    List<LeaveEntry>? leaves,
    List<LeaveTypeOption>? types,
    bool? isLoading,
    bool? isRefreshing,
    bool? typesLoading,
    Object? error = _sentinel,
    LeaveListScope? scope,
    ReportingManagerInfo? reportingInfo,
    bool? reportingLoaded,
    LeaveAdminAllFilters? adminAllFilters,
    List<LeaveBalanceRow>? myBalances,
    bool? balancesLoading,
    Object? balancesError = _sentinel,
  }) {
    return LeaveState(
      leaves: leaves ?? this.leaves,
      types: types ?? this.types,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      typesLoading: typesLoading ?? this.typesLoading,
      error: identical(error, _sentinel) ? this.error : error as String?,
      scope: scope ?? this.scope,
      reportingInfo: reportingInfo ?? this.reportingInfo,
      reportingLoaded: reportingLoaded ?? this.reportingLoaded,
      adminAllFilters: adminAllFilters ?? this.adminAllFilters,
      myBalances: myBalances ?? this.myBalances,
      balancesLoading: balancesLoading ?? this.balancesLoading,
      balancesError: identical(balancesError, _sentinel)
          ? this.balancesError
          : balancesError as String?,
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

  /// Loads remaining days per leave type for the signed-in user.
  Future<void> loadMyBalances() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    state = state.copyWith(balancesLoading: true, balancesError: null);
    try {
      final result = await _repository.getLeaveBalances(userId);
      final sorted = List<LeaveBalanceRow>.from(result.balances)
        ..sort((a, b) {
          final ac = a.isActive == false ? 1 : 0;
          final bc = b.isActive == false ? 1 : 0;
          if (ac != bc) return ac.compareTo(bc);
          return (a.leaveTypeName ?? a.leaveTypeId)
              .toLowerCase()
              .compareTo((b.leaveTypeName ?? b.leaveTypeId).toLowerCase());
        });
      state = state.copyWith(
        myBalances: sorted,
        balancesLoading: false,
        balancesError: null,
      );
    } catch (e) {
      state = state.copyWith(
        balancesLoading: false,
        balancesError: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> loadLeaves({bool refresh = false}) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        error: 'User not authenticated',
      );
      return;
    }
    final flags = beginAsyncLoad(hasCachedData: state.leaves.isNotEmpty);
    if (refresh || state.leaves.isNotEmpty) {
      state = state.copyWith(isRefreshing: true, error: null);
    } else {
      state = state.copyWith(
        isLoading: flags.isLoading,
        isRefreshing: flags.isRefreshing,
        error: null,
      );
    }
    try {
      final leaveElevated = ref.read(leaveManagementElevatedProvider);
      var scope = state.scope;
      if (scope == LeaveListScope.all && !leaveElevated) {
        // Account/scope may be stale after switching users; fall back quietly.
        scope = LeaveListScope.mine;
        state = state.copyWith(scope: scope, error: null);
      }
      if (scope == LeaveListScope.team) {
        final isMgr = state.reportingInfo?.isReportingManager ?? false;
        if (!isMgr && !leaveElevated) {
          // Avoid noisy popup on account switch; show own leaves instead.
          scope = LeaveListScope.mine;
          state = state.copyWith(scope: scope, error: null);
        }
      }

      final list = switch (scope) {
        LeaveListScope.mine => await _repository.getMyLeaves(),
        LeaveListScope.team => await _repository.getTeamLeaves(),
        LeaveListScope.all => await _repository.getAllLeaves(
            startDate: state.adminAllFilters.startDate,
            endDate: state.adminAllFilters.endDate,
            userIds: state.adminAllFilters.userIds.trim().isEmpty
                ? null
                : state.adminAllFilters.userIds.trim(),
          ),
      };
      state = state.copyWith(
        leaves: list,
        isLoading: false,
        isRefreshing: false,
        error: null,
      );
      // Always sync "your remaining leave" after leaves refresh (approve deducts on server).
      await loadMyBalances();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
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
    ref.invalidate(myLeavesForAttendanceProvider);
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
    ref.invalidate(myLeavesForAttendanceProvider);
  }

  Future<void> approveLeave(String leaveId) async {
    await _repository.approveLeave(leaveId);
    await loadLeaves();
    ref.invalidate(myLeavesForAttendanceProvider);
  }

  Future<void> rejectLeave(String leaveId, String reason) async {
    await _repository.rejectLeave(leaveId, reason);
    await loadLeaves();
    ref.invalidate(myLeavesForAttendanceProvider);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  void patchAdminAllFilters({
    DateTime? startDate,
    DateTime? endDate,
    String? userIds,
    bool clearStart = false,
    bool clearEnd = false,
  }) {
    final cur = state.adminAllFilters;
    state = state.copyWith(
      adminAllFilters: LeaveAdminAllFilters(
        startDate: clearStart ? null : (startDate ?? cur.startDate),
        endDate: clearEnd ? null : (endDate ?? cur.endDate),
        userIds: userIds ?? cur.userIds,
      ),
    );
  }

  void clearAdminAllFilters() {
    state = state.copyWith(adminAllFilters: const LeaveAdminAllFilters());
  }

  Future<void> applyAdminAllFiltersAndReload() async {
    await loadLeaves();
  }
}

final leaveProvider =
    StateNotifierProvider<LeaveNotifier, LeaveState>((ref) {
  return LeaveNotifier(ref.watch(leaveRepositoryProvider), ref);
});
