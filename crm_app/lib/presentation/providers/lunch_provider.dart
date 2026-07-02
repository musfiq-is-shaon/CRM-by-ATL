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
    this.myBalanceMonth,
    this.myBalanceLoading = false,
    this.transactions = const [],
    this.voteHistory = const [],
    this.employeeBalances = const [],
    this.employeeBalancesLoading = false,
    this.employeeBalancesFrom,
    this.employeeBalancesTo,
    this.error,
    this.votingPollId,
    this.orderSummaryLoading = false,
  });

  final LunchLoadStatus status;
  final List<LunchPoll> todayPolls;
  final String? selectedPollId;
  final LunchOrderSummary? orderSummary;
  final List<LunchPoll> adminPolls;
  final LunchSettings? settings;
  final LunchDashboardStats? dashboard;
  final LunchBalanceMe? myBalance;
  final String? myBalanceMonth;
  final bool myBalanceLoading;
  final List<LunchBalanceTransaction> transactions;
  final List<LunchVoteHistoryRow> voteHistory;
  final List<LunchEmployeeBalance> employeeBalances;
  final bool employeeBalancesLoading;
  final String? employeeBalancesFrom;
  final String? employeeBalancesTo;
  final String? error;
  final String? votingPollId;
  final bool orderSummaryLoading;

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
    String? myBalanceMonth,
    bool clearMyBalance = false,
    bool? myBalanceLoading,
    List<LunchBalanceTransaction>? transactions,
    List<LunchVoteHistoryRow>? voteHistory,
    List<LunchEmployeeBalance>? employeeBalances,
    bool? employeeBalancesLoading,
    String? employeeBalancesFrom,
    String? employeeBalancesTo,
    bool clearEmployeeBalancesRange = false,
    String? error,
    bool clearError = false,
    String? votingPollId,
    bool clearVoting = false,
    bool? orderSummaryLoading,
  }) {
    return LunchState(
      status: status ?? this.status,
      todayPolls: todayPolls ?? this.todayPolls,
      selectedPollId: selectedPollId ?? this.selectedPollId,
      orderSummary: clearSummary ? null : (orderSummary ?? this.orderSummary),
      adminPolls: adminPolls ?? this.adminPolls,
      settings: settings ?? this.settings,
      dashboard: dashboard ?? this.dashboard,
      myBalance: clearMyBalance ? null : (myBalance ?? this.myBalance),
      myBalanceMonth: myBalanceMonth ?? this.myBalanceMonth,
      myBalanceLoading: myBalanceLoading ?? this.myBalanceLoading,
      transactions: transactions ?? this.transactions,
      voteHistory: voteHistory ?? this.voteHistory,
      employeeBalances: employeeBalances ?? this.employeeBalances,
      employeeBalancesLoading:
          employeeBalancesLoading ?? this.employeeBalancesLoading,
      employeeBalancesFrom: clearEmployeeBalancesRange
          ? null
          : (employeeBalancesFrom ?? this.employeeBalancesFrom),
      employeeBalancesTo: clearEmployeeBalancesRange
          ? null
          : (employeeBalancesTo ?? this.employeeBalancesTo),
      error: clearError ? null : (error ?? this.error),
      votingPollId: clearVoting ? null : (votingPollId ?? this.votingPollId),
      orderSummaryLoading: orderSummaryLoading ?? this.orderSummaryLoading,
    );
  }
}

class LunchNotifier extends StateNotifier<LunchState> {
  LunchNotifier(this._repo) : super(const LunchState());

  final LunchRepository _repo;
  int _balanceRequestId = 0;
  int _employeeBalancesRequestId = 0;
  int _adminPollsRequestId = 0;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _monthKeyFrom(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static (DateTime from, DateTime to) _monthRange(String monthKey) {
    final parts = monthKey.split('-');
    final year = int.tryParse(parts.first) ?? DateTime.now().year;
    final month = int.tryParse(parts.length > 1 ? parts[1] : '1') ?? 1;
    final from = DateTime(year, month, 1);
    final to = DateTime(year, month + 1, 0);
    return (from, to);
  }

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
    final previousToday = state.todayPolls;
    state = state.copyWith(
      todayPolls: [
        for (final p in state.todayPolls)
          if (p.id == pollId) p.withMyVote(optionId) else p,
      ],
    );
    try {
      await _repo.castVote(pollId, optionId);
      try {
        LunchPoll? existing;
        for (final p in state.todayPolls) {
          if (p.id == pollId) {
            existing = p;
            break;
          }
        }
        if (existing == null) return;

        LunchPoll refreshed;
        LunchPoll? todayPeer;
        try {
          final results = await Future.wait<Object>([
            _repo.refreshPollHydrated(pollId),
            _repo.getTodayPolls(),
          ]);
          refreshed = results[0] as LunchPoll;
          final bundle = results[1] as LunchTodayBundle;
          for (final p in bundle.items) {
            if (p.id == pollId) {
              todayPeer = p;
              break;
            }
          }
        } catch (_) {
          refreshed = existing;
        }

        var merged = LunchPoll.mergeAfterVote(local: existing, server: refreshed);
        final todayVote = todayPeer?.scopedMyVote;
        if (todayVote != null && todayVote.optionId.isNotEmpty) {
          merged = LunchPoll(
            id: merged.id,
            title: merged.title,
            date: merged.date,
            costAmount: merged.costAmount,
            allowVoteChange: merged.allowVoteChange,
            endTime: merged.endTime,
            status: merged.status,
            options: merged.options,
            results: merged.results,
            myVote: todayVote,
            reportedTotalVotes: merged.reportedTotalVotes,
          );
        }
        _upsertPoll(merged);
        final month = state.myBalanceMonth ?? _monthKeyFrom(DateTime.now());
        await loadMyBalance(month: month, silent: true);
      } catch (_) {
        // Keep optimistic state if refresh fails.
      }
    } catch (e) {
      state = state.copyWith(todayPolls: previousToday, error: e.toString());
    } finally {
      state = state.copyWith(clearVoting: true);
    }
  }

  /// Loads today's (or recent) poll summary without flashing partial UI.
  Future<void> bootstrapOrderSummary() async {
    state = state.copyWith(
      orderSummaryLoading: true,
      clearError: true,
      clearSummary: state.orderSummary == null,
    );
    try {
      await loadTodayPolls(silent: true);
      final pollId = state.selectedPollId ??
          (state.todayPolls.isNotEmpty ? state.todayPolls.first.id : null);
      if (pollId != null && pollId.isNotEmpty) {
        await loadOrderSummary(pollId, silent: state.orderSummary != null);
        return;
      }
      final now = DateTime.now();
      final polls = await _repo.fetchPollPickerList(
        from: now.subtract(const Duration(days: 7)),
        to: now,
      );
      if (polls.isNotEmpty) {
        await loadOrderSummary(polls.first.id, silent: state.orderSummary != null);
      } else {
        state = state.copyWith(orderSummaryLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        orderSummaryLoading: false,
      );
    }
  }

  Future<void> loadOrderSummary(String pollId, {bool silent = false}) async {
    final keepSummary =
        silent && state.selectedPollId == pollId && state.orderSummary != null;
    state = state.copyWith(
      selectedPollId: pollId,
      clearError: true,
      clearSummary: !keepSummary,
      orderSummaryLoading: !keepSummary,
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
        orderSummary: summary,
        selectedPollId: pollId,
        orderSummaryLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        orderSummaryLoading: false,
      );
    }
  }

  Future<void> loadAdminPolls({
    required DateTime from,
    required DateTime to,
    String? status,
    bool silent = false,
    bool hydrate = true,
  }) async {
    final requestId = ++_adminPollsRequestId;
    final hadPolls = state.adminPolls.isNotEmpty;
    if (!silent) {
      state = state.copyWith(status: LunchLoadStatus.loading, clearError: true);
    }
    try {
      final polls = hydrate
          ? await _repo.listPollsHydrated(from: from, to: to, status: status)
          : await _repo.listPolls(from: from, to: to, status: status);
      if (requestId != _adminPollsRequestId) return;
      state = state.copyWith(
        status: LunchLoadStatus.loaded,
        adminPolls: polls,
        selectedPollId: state.selectedPollId ?? (polls.isNotEmpty ? polls.first.id : null),
      );
    } catch (e) {
      if (requestId != _adminPollsRequestId) return;
      state = state.copyWith(
        status: hadPolls ? LunchLoadStatus.loaded : LunchLoadStatus.error,
        error: e.toString(),
      );
    }
  }

  /// Fast poll list for order-summary picker (no per-poll vote hydration).
  Future<List<LunchPoll>> loadPollPickerOptions({
    required DateTime from,
    required DateTime to,
  }) {
    return _repo.fetchPollPickerList(from: from, to: to);
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

  Future<void> loadMyBalance({String? month, bool silent = false}) async {
    final monthKey = month ?? _monthKeyFrom(DateTime.now());
    final requestId = ++_balanceRequestId;
    final keepExisting =
        silent && state.myBalanceMonth == monthKey && state.myBalance != null;

    if (!silent) {
      state = state.copyWith(status: LunchLoadStatus.loading, clearError: true);
    }
    state = state.copyWith(
      myBalanceLoading: !keepExisting,
      myBalanceMonth: monthKey,
      clearMyBalance: !keepExisting,
    );

    try {
      final bal = await _repo.getMyBalance(month: monthKey);
      if (requestId != _balanceRequestId) return;

      final (from, to) = _monthRange(monthKey);
      final tx = await _repo.getBalanceTransactions(from: from, to: to);
      if (requestId != _balanceRequestId) return;

      state = state.copyWith(
        status: LunchLoadStatus.loaded,
        myBalance: bal,
        myBalanceMonth: monthKey,
        myBalanceLoading: false,
        transactions: tx,
      );
    } catch (e) {
      if (requestId != _balanceRequestId) return;
      state = state.copyWith(
        status: LunchLoadStatus.error,
        myBalanceLoading: false,
        error: e.toString(),
      );
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
    final requestId = ++_employeeBalancesRequestId;
    final fromDate = _dateOnly(from);
    final toDate = _dateOnly(to);

    state = state.copyWith(
      employeeBalancesLoading: true,
      employeeBalances: const [],
      clearEmployeeBalancesRange: true,
      clearError: true,
    );
    try {
      final rows = await _repo.getEmployeeBalances(from: fromDate, to: toDate);
      if (requestId != _employeeBalancesRequestId) return;
      state = state.copyWith(
        employeeBalances: rows,
        employeeBalancesLoading: false,
        employeeBalancesFrom: _dateKey(fromDate),
        employeeBalancesTo: _dateKey(toDate),
      );
    } catch (e) {
      if (requestId != _employeeBalancesRequestId) return;
      state = state.copyWith(
        employeeBalancesLoading: false,
        error: e.toString(),
      );
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
    loadTodayPolls(silent: true);
    return created;
  }

  Future<LunchPoll> updatePoll(
    String pollId,
    LunchPoll poll, {
    LunchPoll? original,
  }) async {
    var updated = poll;
    for (final payload in poll.toUpdateJsonSequence(original: original)) {
      updated = await _repo.updatePoll(pollId, payload);
    }
    // Polls admin page reloads with hydrate: true after save — avoid racing
    // an unhydrated list refresh that briefly clears vote counts on cards.
    loadTodayPolls(silent: true);
    return updated;
  }

  Future<void> closePoll(String pollId) async {
    await _repo.setPollStatus(pollId, 'closed');
    await loadTodayPolls(silent: true);
    if (state.selectedPollId == pollId) {
      await loadOrderSummary(pollId, silent: state.orderSummary != null);
    }
  }

  Future<void> deletePoll(String pollId) async {
    await _repo.deletePoll(pollId);
    final wasSelected = state.selectedPollId == pollId;
    final today = [
      for (final p in state.todayPolls)
        if (p.id != pollId) p,
    ];
    final admin = [
      for (final p in state.adminPolls)
        if (p.id != pollId) p,
    ];
    state = state.copyWith(
      todayPolls: today,
      adminPolls: admin,
      clearSummary: wasSelected,
      selectedPollId: wasSelected
          ? (today.isNotEmpty ? today.first.id : null)
          : state.selectedPollId,
      clearError: true,
    );
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
