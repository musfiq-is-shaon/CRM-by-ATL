import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/rbac_page_keys.dart';
import '../../data/models/lunch_model.dart';
import '../../data/repositories/lunch_repository.dart';
import 'auth_provider.dart';
import 'rbac_provider.dart';

enum LunchLoadStatus { idle, loading, loaded, error }

class LunchState {
  const LunchState({
    this.status = LunchLoadStatus.idle,
    this.todayPolls = const [],
    this.selectedPollId,
    this.orderSummary,
    this.adminPolls = const [],
    this.settings,
    this.dashboard,
    this.myBalance,
    this.transactions = const [],
    this.voteHistory = const [],
    this.employeeBalances = const [],
    this.error,
    this.votingPollId,
  });

  final LunchLoadStatus status;
  final List<LunchPoll> todayPolls;
  final String? selectedPollId;
  final LunchOrderSummary? orderSummary;
  final List<LunchPoll> adminPolls;
  final LunchSettings? settings;
  final LunchDashboardStats? dashboard;
  final LunchBalanceMe? myBalance;
  final List<LunchBalanceTransaction> transactions;
  final List<LunchVoteHistoryRow> voteHistory;
  final List<LunchEmployeeBalance> employeeBalances;
  final String? error;
  final String? votingPollId;

  LunchPoll? get selectedPoll {
    if (selectedPollId == null) return todayPolls.isNotEmpty ? todayPolls.first : null;
    for (final p in todayPolls) {
      if (p.id == selectedPollId) return p;
    }
    for (final p in adminPolls) {
      if (p.id == selectedPollId) return p;
    }
    return null;
  }

  LunchState copyWith({
    LunchLoadStatus? status,
    List<LunchPoll>? todayPolls,
    String? selectedPollId,
    LunchOrderSummary? orderSummary,
    bool clearSummary = false,
    List<LunchPoll>? adminPolls,
    LunchSettings? settings,
    LunchDashboardStats? dashboard,
    LunchBalanceMe? myBalance,
    List<LunchBalanceTransaction>? transactions,
    List<LunchVoteHistoryRow>? voteHistory,
    List<LunchEmployeeBalance>? employeeBalances,
    String? error,
    bool clearError = false,
    String? votingPollId,
    bool clearVoting = false,
  }) {
    return LunchState(
      status: status ?? this.status,
      todayPolls: todayPolls ?? this.todayPolls,
      selectedPollId: selectedPollId ?? this.selectedPollId,
      orderSummary: clearSummary ? null : (orderSummary ?? this.orderSummary),
      adminPolls: adminPolls ?? this.adminPolls,
      settings: settings ?? this.settings,
      dashboard: dashboard ?? this.dashboard,
      myBalance: myBalance ?? this.myBalance,
      transactions: transactions ?? this.transactions,
      voteHistory: voteHistory ?? this.voteHistory,
      employeeBalances: employeeBalances ?? this.employeeBalances,
      error: clearError ? null : (error ?? this.error),
      votingPollId: clearVoting ? null : (votingPollId ?? this.votingPollId),
    );
  }
}

class LunchNotifier extends StateNotifier<LunchState> {
  LunchNotifier(this._repo) : super(const LunchState());

  final LunchRepository _repo;

  void _upsertPoll(LunchPoll poll) {
    if (poll.id.isEmpty) return;
    final today = [
      for (final p in state.todayPolls) p.id == poll.id ? poll : p,
    ];
    final admin = [
      for (final p in state.adminPolls) p.id == poll.id ? poll : p,
    ];
    state = state.copyWith(todayPolls: today, adminPolls: admin);
  }

  Future<void> bootstrapUser() async {
    state = state.copyWith(status: LunchLoadStatus.loading, clearError: true);
    try {
      final polls = await _repo.getTodayPollsHydrated();
      state = state.copyWith(
        status: LunchLoadStatus.loaded,
        todayPolls: polls,
        selectedPollId: polls.isNotEmpty ? polls.first.id : null,
      );
    } catch (e) {
      state = state.copyWith(status: LunchLoadStatus.error, error: e.toString());
    }
  }

  Future<void> loadTodayPolls({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(status: LunchLoadStatus.loading, clearError: true);
    }
    try {
      final polls = await _repo.getTodayPollsHydrated();
      state = state.copyWith(
        status: LunchLoadStatus.loaded,
        todayPolls: polls,
        selectedPollId: state.selectedPollId ?? (polls.isNotEmpty ? polls.first.id : null),
      );
    } catch (e) {
      state = state.copyWith(status: LunchLoadStatus.error, error: e.toString());
    }
  }

  Future<void> vote(String pollId, String optionId) async {
    state = state.copyWith(votingPollId: pollId, clearError: true);
    try {
      await _repo.castVote(pollId, optionId);
      await loadTodayPolls(silent: true);
      if (state.selectedPollId == pollId) {
        await loadOrderSummary(pollId);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(clearVoting: true);
    }
  }

  Future<void> loadOrderSummary(String pollId) async {
    state = state.copyWith(
      selectedPollId: pollId,
      status: LunchLoadStatus.loading,
      clearError: true,
      clearSummary: true,
    );
    try {
      LunchPoll? poll;
      for (final p in state.todayPolls) {
        if (p.id == pollId) poll = p;
      }
      for (final p in state.adminPolls) {
        if (p.id == pollId) poll = p;
      }
      poll ??= await _repo.getPoll(pollId);
      final summary = await _repo.getPollSummary(pollId, poll: poll);
      _upsertPoll(summary.poll);
      state = state.copyWith(
        status: LunchLoadStatus.loaded,
        orderSummary: summary,
        selectedPollId: pollId,
      );
    } catch (e) {
      state = state.copyWith(status: LunchLoadStatus.error, error: e.toString());
    }
  }

  Future<void> loadAdminPolls({
    required DateTime from,
    required DateTime to,
    String? status,
  }) async {
    state = state.copyWith(status: LunchLoadStatus.loading, clearError: true);
    try {
      final polls = await _repo.listPollsHydrated(from: from, to: to, status: status);
      state = state.copyWith(
        status: LunchLoadStatus.loaded,
        adminPolls: polls,
        selectedPollId: state.selectedPollId ?? (polls.isNotEmpty ? polls.first.id : null),
      );
    } catch (e) {
      state = state.copyWith(status: LunchLoadStatus.error, error: e.toString());
    }
  }

  Future<void> loadSettings() async {
    try {
      final settings = await _repo.getSettings();
      state = state.copyWith(settings: settings);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> saveSettings(LunchSettings settings) async {
    state = state.copyWith(status: LunchLoadStatus.loading, clearError: true);
    try {
      final saved = await _repo.updateSettings(settings);
      state = state.copyWith(status: LunchLoadStatus.loaded, settings: saved);
    } catch (e) {
      state = state.copyWith(status: LunchLoadStatus.error, error: e.toString());
      rethrow;
    }
  }

  Future<void> loadDashboard() async {
    try {
      final dash = await _repo.getDashboard();
      state = state.copyWith(dashboard: dash);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> loadMyBalance({String? month}) async {
    state = state.copyWith(status: LunchLoadStatus.loading, clearError: true);
    try {
      final bal = await _repo.getMyBalance(month: month);
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, 1);
      final to = DateTime(now.year, now.month + 1, 0);
      final tx = await _repo.getBalanceTransactions(from: from, to: to);
      state = state.copyWith(
        status: LunchLoadStatus.loaded,
        myBalance: bal,
        transactions: tx,
      );
    } catch (e) {
      state = state.copyWith(status: LunchLoadStatus.error, error: e.toString());
    }
  }

  Future<void> loadVoteHistory({
    required DateTime from,
    required DateTime to,
    String? optionType,
  }) async {
    state = state.copyWith(status: LunchLoadStatus.loading, clearError: true);
    try {
      final rows = await _repo.getVoteHistory(
        from: from,
        to: to,
        optionType: optionType,
      );
      state = state.copyWith(status: LunchLoadStatus.loaded, voteHistory: rows);
    } catch (e) {
      state = state.copyWith(status: LunchLoadStatus.error, error: e.toString());
    }
  }

  Future<void> loadEmployeeBalances({
    required DateTime from,
    required DateTime to,
  }) async {
    state = state.copyWith(status: LunchLoadStatus.loading, clearError: true);
    try {
      final rows = await _repo.getEmployeeBalances(from: from, to: to);
      state = state.copyWith(
        status: LunchLoadStatus.loaded,
        employeeBalances: rows,
      );
    } catch (e) {
      state = state.copyWith(status: LunchLoadStatus.error, error: e.toString());
    }
  }

  Future<void> adjustBalance({
    required String userId,
    required num amount,
    required String reason,
  }) async {
    await _repo.adjustBalance(userId: userId, amount: amount, reason: reason);
  }

  Future<LunchPoll> createPoll(LunchPoll poll) async {
    final created = await _repo.createPoll(poll);
    await loadTodayPolls(silent: true);
    return created;
  }

  Future<LunchPoll> updatePoll(String pollId, LunchPoll poll) async {
    final updated = await _repo.updatePoll(pollId, poll.toUpdateJson());
    await loadTodayPolls(silent: true);
    return updated;
  }

  Future<void> closePoll(String pollId) async {
    await _repo.setPollStatus(pollId, 'closed');
    await loadTodayPolls(silent: true);
    if (state.selectedPollId == pollId) {
      await loadOrderSummary(pollId);
    }
  }

  Future<void> deletePoll(String pollId) async {
    await _repo.deletePoll(pollId);
    await loadTodayPolls(silent: true);
  }

  void clearError() => state = state.copyWith(clearError: true);

  void clear() => state = const LunchState();
}

final lunchProvider = StateNotifierProvider<LunchNotifier, LunchState>((ref) {
  return LunchNotifier(ref.watch(lunchRepositoryProvider));
});

final lunchAdminProvider = Provider<bool>((ref) {
  if (ref.watch(isAdminProvider)) return true;
  return ref.watch(rbacMeProvider)?.isModuleAdmin(RbacPageKey.lunch) ?? false;
});

final lunchModuleVisibleProvider = Provider<bool>((ref) {
  if (ref.watch(isAdminProvider)) {
    return ref.watch(rbacMeProvider)?.hasModuleAccess(RbacPageKey.lunch) ?? true;
  }
  return ref.watch(rbacMeProvider)?.hasNav(RbacPageKey.lunch) ?? false;
});
