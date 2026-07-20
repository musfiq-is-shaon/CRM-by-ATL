import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/async_load_helper.dart';
import '../../core/errors/exceptions.dart';
import '../../data/models/attendance_model.dart';
import '../../data/repositories/attendance_repository.dart';
import 'auth_provider.dart';

class AttendanceReconciliationState {
  final List<AttendanceReconciliation> items;
  final bool isLoading;
  final bool isRefreshing;
  final String? error;
  final String? statusFilter;

  const AttendanceReconciliationState({
    this.items = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
    this.statusFilter,
  });

  AttendanceReconciliationState copyWith({
    List<AttendanceReconciliation>? items,
    bool? isLoading,
    bool? isRefreshing,
    String? error,
    String? statusFilter,
  }) {
    return AttendanceReconciliationState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: error,
      statusFilter: statusFilter ?? this.statusFilter,
    );
  }
}

class AttendanceReconciliationNotifier
    extends StateNotifier<AttendanceReconciliationState> {
  AttendanceReconciliationNotifier(this._repository, this.ref)
    : super(const AttendanceReconciliationState());

  final AttendanceRepository _repository;
  final Ref ref;

  /// Own submissions only. Passes [userId] so admins are not returned the full org list from GET.
  Future<void> loadMine({String? status}) async {
    state = state.copyWith(isLoading: true, error: null, statusFilter: status);
    try {
      final uid = ref.read(currentUserIdProvider)?.trim();
      if (uid == null || uid.isEmpty) {
        state = state.copyWith(items: [], isLoading: false);
        return;
      }
      var list = await _repository.getReconciliations(
        status: status,
        userId: uid,
      );
      // Safety net: server may ignore userId for admins; also normalize Mongo/string ids.
      list = list
          .where(
            (r) => attendanceUserIdsEqual(r.effectiveApplicantUserId, uid),
          )
          .toList();
      state = state.copyWith(items: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Admin / reviewer: pending team queue (optional filters).
  Future<void> loadTeamQueue({
    String status = 'pending',
    String? userId,
    String? dateFrom,
    String? dateTo,
    bool refresh = false,
  }) async {
    final hadCache = state.items.isNotEmpty;
    if (!hadCache) {
      state = state.copyWith(
        isLoading: true,
        isRefreshing: false,
        error: null,
        statusFilter: status,
      );
    } else if (refresh) {
      state = state.copyWith(
        isRefreshing: true,
        error: null,
        statusFilter: status,
      );
    } else {
      final flags = beginAsyncLoad(hasCachedData: true);
      state = state.copyWith(
        isLoading: flags.isLoading,
        isRefreshing: flags.isRefreshing,
        error: null,
        statusFilter: status,
      );
    }
    try {
      final list = await _repository.getReconciliations(
        status: status,
        userId: userId,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
      state = state.copyWith(
        items: list,
        isLoading: false,
        isRefreshing: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        error: asyncLoadError(e),
      );
    }
  }

  Future<void> submitReason({
    required String attendanceId,
    required String reason,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.createReconciliation(
        attendanceId: attendanceId,
        reason: reason,
      );
      await loadMine();
    } catch (e) {
      final msg = e is AppException ? e.message : e.toString();
      state = state.copyWith(isLoading: false, error: msg);
      rethrow;
    }
  }

  Future<void> review({
    required String reconciliationId,
    required String status,
    String? reviewNote,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.reviewReconciliation(
        reconciliationId: reconciliationId,
        status: status,
        reviewNote: reviewNote,
      );
      await loadTeamQueue(status: 'pending');
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final attendanceReconciliationProvider = StateNotifierProvider<
    AttendanceReconciliationNotifier, AttendanceReconciliationState>(
  (ref) {
    final repo = ref.watch(attendanceRepositoryProvider);
    return AttendanceReconciliationNotifier(repo, ref);
  },
);
