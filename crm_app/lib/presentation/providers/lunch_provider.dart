import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/rbac_page_keys.dart';
import '../../core/utils/lunch_poll_schedule.dart';
import '../../data/models/lunch_model.dart';
import '../../data/repositories/lunch_repository.dart';
import 'auth_provider.dart';
import 'rbac_provider.dart';

bool _isPollVotingOpen(LunchPoll poll) {
  if (poll.isCancelled) return false;
  if (poll.status.toLowerCase() != 'active') return false;
  return !lunchPollIsPastEndTime(
    endTime: poll.endTime,
    pollDate: poll.date,
    status: poll.status,
  );
}

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
    this.voteHistoryLoading = false,
    this.voteHistoryError,
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
  final bool voteHistoryLoading;
  final String? voteHistoryError;
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
    bool? voteHistoryLoading,
    String? voteHistoryError,
    bool clearVoteHistoryError = false,
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
      voteHistoryLoading: voteHistoryLoading ?? this.voteHistoryLoading,
      voteHistoryError: clearVoteHistoryError
          ? null
          : (voteHistoryError ?? this.voteHistoryError),
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
  LunchNotifier(this._repo, this._ref) : super(const LunchState());

  final LunchRepository _repo;
  final Ref _ref;
  int _balanceRequestId = 0;
  int _employeeBalancesRequestId = 0;
  int _adminPollsRequestId = 0;
  Future<void>? _bootstrapInFlight;
  bool _todayPollsStale = false;

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

  bool _showOnMyLunch(LunchPoll poll) => poll.resolvedForMyLunch().showOnMyLunch;

  void _upsertPoll(LunchPoll poll) {
    if (poll.id.isEmpty) return;
    LunchPoll? prior;
    for (final p in state.todayPolls) {
      if (p.id == poll.id) {
        prior = p;
        break;
      }
    }
    if (prior == null) {
      for (final p in state.adminPolls) {
        if (p.id == poll.id) {
          prior = p;
          break;
        }
      }
    }
    final merged = prior?.applyServerSnapshot(poll) ?? poll;

    var today = <LunchPoll>[
      for (final p in state.todayPolls) p.id == poll.id ? merged : p,
    ];
    if (!today.any((p) => p.id == merged.id) && _showOnMyLunch(merged)) {
      today = sortTodayPollsNewestFirst(dedupeTodayPolls([...today, merged]));
    }

    var admin = <LunchPoll>[
      for (final p in state.adminPolls) p.id == poll.id ? merged : p,
    ];
    if (!admin.any((p) => p.id == merged.id)) {
      admin = sortTodayPollsNewestFirst(dedupeTodayPolls([...admin, merged]));
    }

    state = state.copyWith(todayPolls: today, adminPolls: admin);
  }

  List<LunchPoll> _mergeTodayPollLists(
    List<LunchPoll> existing,
    List<LunchPoll> incoming,
  ) {
    final priorById = {for (final p in existing) p.id: p};
    final incomingIds = {for (final p in incoming) if (p.id.isNotEmpty) p.id};

    final merged = <LunchPoll>[
      for (final poll in incoming)
        (priorById[poll.id]?.applyServerSnapshot(poll) ?? poll)
            .resolvedForMyLunch(),
    ];

    void retainIfMissing(LunchPoll prior) {
      if (prior.id.isEmpty || incomingIds.contains(prior.id)) return;
      if (merged.any((p) => p.id == prior.id)) return;
      final resolved = prior.resolvedForMyLunch();
      if (!resolved.showOnMyLunch) return;
      merged.add(resolved);
    }

    for (final prior in existing) {
      retainIfMissing(prior);
    }
    for (final prior in state.adminPolls) {
      retainIfMissing(priorById[prior.id] ?? prior);
    }

    return sortTodayPollsNewestFirst(dedupeTodayPolls(merged));
  }

  List<LunchPoll> _mergePollLists(List<LunchPoll> existing, List<LunchPoll> incoming) {
    final priorById = {for (final p in existing) p.id: p};
    return [
      for (final poll in incoming)
        priorById[poll.id]?.applyServerSnapshot(poll) ?? poll,
    ];
  }

  void _patchPollStatus(
    String pollId,
    String status, {
    String? endTime,
    bool? allowVoteChange,
  }) {
    LunchPoll apply(LunchPoll p) {
      if (p.id != pollId) return p;
      return LunchPoll(
        id: p.id,
        title: p.title,
        date: p.date,
        createdAt: p.createdAt,
        costAmount: p.costAmount,
        allowVoteChange: allowVoteChange ?? p.allowVoteChange,
        endTime: endTime ?? p.endTime,
        status: status,
        options: p.options,
        results: p.results,
        myVote: p.myVote,
        reportedTotalVotes: p.reportedTotalVotes,
      );
    }

    state = state.copyWith(
      todayPolls: [for (final p in state.todayPolls) apply(p)],
      adminPolls: [for (final p in state.adminPolls) apply(p)],
    );
  }

  Future<void> _refreshPollInState(
    String pollId, {
    String? preserveEndTime,
    String? preserveStatus,
  }) async {
    try {
      LunchPoll? prior;
      for (final p in [...state.todayPolls, ...state.adminPolls]) {
        if (p.id == pollId) {
          prior = p;
          break;
        }
      }

      var fresh = await _repo.refreshPollHydrated(
        pollId,
        currentUserId: _currentUserId,
      );
      final keptEnd = preserveEndTime?.trim();
      final keptStatus = preserveStatus?.trim();
      if (keptStatus != null && keptStatus.isNotEmpty) {
        fresh = LunchPoll(
          id: fresh.id,
          title: fresh.title,
          date: fresh.date,
          createdAt: fresh.createdAt,
          costAmount: fresh.costAmount,
          allowVoteChange: prior?.allowVoteChange ?? fresh.allowVoteChange,
          endTime: (keptEnd != null && keptEnd.isNotEmpty)
              ? keptEnd
              : fresh.endTime,
          status: keptStatus,
          options: fresh.options,
          results: fresh.results,
          myVote: fresh.myVote ?? prior?.myVote,
          reportedTotalVotes: fresh.reportedTotalVotes,
        );
      } else if (keptEnd != null && keptEnd.isNotEmpty) {
        fresh = LunchPoll(
          id: fresh.id,
          title: fresh.title,
          date: fresh.date,
          createdAt: fresh.createdAt,
          costAmount: fresh.costAmount,
          allowVoteChange: prior?.allowVoteChange ?? true,
          endTime: keptEnd,
          status: preserveStatus ??
              (fresh.status.toLowerCase() == 'closed' ? 'active' : fresh.status),
          options: fresh.options,
          results: fresh.results,
          myVote: fresh.myVote ?? prior?.myVote,
          reportedTotalVotes: fresh.reportedTotalVotes,
        );
      } else if (prior != null) {
        fresh = prior.applyServerSnapshot(fresh);
      }
      _upsertPoll(fresh);
    } catch (_) {}
  }

  String? get _currentUserId => _ref.read(currentUserIdProvider);

  Future<void> bootstrapUser({bool force = false}) async {
    if (!force) {
      if (state.status == LunchLoadStatus.loaded &&
          state.todayPolls.isNotEmpty &&
          !_todayPollsStale) {
        return;
      }
      if (_bootstrapInFlight != null) {
        await _bootstrapInFlight;
        return;
      }
    }

    final future = _bootstrapUserImpl();
    _bootstrapInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_bootstrapInFlight, future)) {
        _bootstrapInFlight = null;
      }
    }
  }

  Future<void> _bootstrapUserImpl() async {
    if (state.todayPolls.isEmpty) {
      state = state.copyWith(status: LunchLoadStatus.loading, clearError: true);
    }
    try {
      final polls = await _repo.getTodayPollsHydrated(
        currentUserId: _currentUserId,
      );
      state = state.copyWith(
        status: LunchLoadStatus.loaded,
        todayPolls: _mergeTodayPollLists(state.todayPolls, polls),
        selectedPollId: state.selectedPollId ??
            (polls.isNotEmpty ? polls.first.id : null),
      );
      _todayPollsStale = false;
    } catch (e) {
      state = state.copyWith(status: LunchLoadStatus.error, error: e.toString());
    }
  }

  Future<void> loadTodayPolls({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(status: LunchLoadStatus.loading, clearError: true);
    }
    try {
      final polls = await _repo.getTodayPollsHydrated(
        currentUserId: _currentUserId,
      );
      _todayPollsStale = false;
      state = state.copyWith(
        status: LunchLoadStatus.loaded,
        todayPolls: _mergeTodayPollLists(state.todayPolls, polls),
        selectedPollId: state.selectedPollId ??
            (polls.isNotEmpty ? polls.first.id : null),
      );
    } catch (e) {
      state = state.copyWith(status: LunchLoadStatus.error, error: e.toString());
    }
  }

  void _markTodayPollsStale() => _todayPollsStale = true;

  /// Refreshes My Lunch when admin changed polls on another tab.
  Future<void> refreshTodayPollsIfStale() async {
    if (!_todayPollsStale) return;
    await loadTodayPolls(silent: true);
  }

  Future<void> vote(String pollId, String optionId) async {
    LunchPoll? target;
    for (final p in state.todayPolls) {
      if (p.id == pollId) {
        target = p;
        break;
      }
    }

    state = state.copyWith(votingPollId: pollId, clearError: true);
    final previousToday = state.todayPolls;
    state = state.copyWith(
      todayPolls: [
        for (final p in state.todayPolls)
          if (p.id == pollId) p.withMyVote(optionId) else p,
      ],
    );
    try {
      final liveTarget = state.todayPolls
          .where((p) => p.id == pollId)
          .fold<LunchPoll?>(null, (_, p) => p);
      await _repo.castVote(
        pollId,
        optionId,
        poll: liveTarget ?? target,
      );
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
        try {
          refreshed = await _repo.refreshPollHydrated(
            pollId,
            currentUserId: _currentUserId,
          );
        } catch (_) {
          refreshed = existing;
        }

        var merged = LunchPoll.mergeAfterVote(local: existing, server: refreshed);
        _upsertPoll(merged);
        final month = state.myBalanceMonth ?? _monthKeyFrom(DateTime.now());
        unawaited(loadMyBalance(month: month, silent: true));
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
      if (state.todayPolls.isEmpty) {
        await loadTodayPolls(silent: true);
      }
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
    try {
      final polls = hydrate
          ? await _repo.listPollsHydrated(
              from: from,
              to: to,
              status: status,
              currentUserId: _currentUserId,
              includeMyVote: false,
            )
          : await _repo.listPolls(from: from, to: to, status: status);
      if (requestId != _adminPollsRequestId) return;
      final merged = _mergePollLists(state.adminPolls, polls)
          .map((p) => p.withoutMyVote())
          .toList();
      state = state.copyWith(
        adminPolls: merged,
        selectedPollId: state.selectedPollId ??
            (merged.isNotEmpty ? merged.first.id : null),
      );
      if (!hydrate && polls.isNotEmpty) {
        unawaited(
          _enrichAdminPollsInBackground(
            from: from,
            to: to,
            status: status,
            requestId: requestId,
          ),
        );
      }
    } catch (e) {
      if (requestId != _adminPollsRequestId) return;
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> _enrichAdminPollsInBackground({
    required DateTime from,
    required DateTime to,
    String? status,
    required int requestId,
  }) async {
    try {
      final polls = await _repo.listPollsHydrated(
        from: from,
        to: to,
        status: status,
        currentUserId: _currentUserId,
        includeMyVote: false,
      );
      if (requestId != _adminPollsRequestId) return;
      state = state.copyWith(
        adminPolls: _mergePollLists(state.adminPolls, polls)
            .map((p) => p.withoutMyVote())
            .toList(),
        selectedPollId: state.selectedPollId ?? (polls.isNotEmpty ? polls.first.id : null),
      );
    } catch (_) {}
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
      final (from, to) = _monthRange(monthKey);
      final results = await Future.wait([
        _repo.getMyBalance(month: monthKey),
        _repo.getBalanceTransactions(from: from, to: to),
      ]);
      if (requestId != _balanceRequestId) return;
      final bal = results[0] as LunchBalanceMe;
      final tx = results[1] as List<LunchBalanceTransaction>;

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
    state = state.copyWith(
      voteHistoryLoading: true,
      clearVoteHistoryError: true,
    );
    try {
      final rows = await _repo.getVoteHistory(
        from: from,
        to: to,
        optionType: optionType,
      );
      state = state.copyWith(
        voteHistoryLoading: false,
        voteHistory: rows,
      );
    } catch (e) {
      state = state.copyWith(
        voteHistoryLoading: false,
        voteHistoryError: e.toString(),
      );
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
    _markTodayPollsStale();
    unawaited(loadTodayPolls(silent: true));
    return created;
  }

  Future<LunchPoll> updatePoll(
    String pollId,
    LunchPoll poll, {
    LunchPoll? original,
    LunchPoll? priorState,
  }) async {
    var updated = poll;
    for (final payload in poll.toUpdateJsonSequence(original: original)) {
      updated = await _repo.updatePoll(pollId, payload);
    }

    final endApi = poll.endTime?.trim();
    final pollDate = poll.date ?? priorState?.date ?? original?.date;
    final reopenRef = priorState ?? original;
    if (reopenRef != null &&
        endApi != null &&
        endApi.isNotEmpty &&
        isPollEndTimeViable(endApi, pollDate) &&
        !_isPollVotingOpen(reopenRef)) {
      updated = await _repo.reopenPoll(
        pollId,
        endTimeApi: endApi,
        allowVoteChange:
            poll.isPriorDayPoll ? false : poll.allowVoteChange,
      );
      _patchPollStatus(
        pollId,
        'active',
        endTime: endApi,
        allowVoteChange: poll.isPriorDayPoll ? false : poll.allowVoteChange,
      );
      _upsertPoll(updated);
      unawaited(_ensurePollVisibleOnMyLunch(pollId, endTime: endApi));
    } else {
      _upsertPoll(updated);
    }

    _markTodayPollsStale();
    unawaited(loadTodayPolls(silent: true));
    return updated;
  }

  Future<void> closePoll(String pollId) async {
    _markTodayPollsStale();
    await _repo.setPollStatus(pollId, 'closed');
    _patchPollStatus(pollId, 'closed');
    await _refreshPollInState(pollId, preserveStatus: 'closed');
    try {
      await loadTodayPolls(silent: true);
    } catch (_) {}
  }

  Future<void> _ensurePollVisibleOnMyLunch(
    String pollId, {
    String? endTime,
  }) async {
    try {
      LunchPoll? prior;
      for (final p in [...state.todayPolls, ...state.adminPolls]) {
        if (p.id == pollId) {
          prior = p;
          break;
        }
      }

      var poll = await _repo.refreshPollHydrated(
        pollId,
        currentUserId: _currentUserId,
      );
      final keptEnd = endTime?.trim();
      if (keptEnd != null && keptEnd.isNotEmpty) {
        poll = LunchPoll(
          id: poll.id,
          title: poll.title,
          date: poll.date,
          createdAt: poll.createdAt,
          costAmount: poll.costAmount,
          allowVoteChange: prior?.allowVoteChange ?? true,
          endTime: keptEnd,
          status: 'active',
          options: poll.options,
          results: poll.results,
          myVote: poll.myVote ?? prior?.myVote,
          reportedTotalVotes: poll.reportedTotalVotes,
        ).withPollScopedVotes();
      } else if (prior != null) {
        poll = prior.applyServerSnapshot(poll);
      }
      if (_showOnMyLunch(poll)) {
        _upsertPoll(poll);
      }
    } catch (_) {}
  }

  Future<void> deletePoll(String pollId) async {
    _markTodayPollsStale();
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
  return LunchNotifier(ref.watch(lunchRepositoryProvider), ref);
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
