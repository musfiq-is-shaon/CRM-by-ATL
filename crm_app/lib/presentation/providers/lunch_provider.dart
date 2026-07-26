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
    this.employeeBalancesError,
    this.adminPollsError,
    this.orderSummaryError,
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
  final String? employeeBalancesError;
  final String? adminPollsError;
  final String? orderSummaryError;
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
    bool clearSelectedPollId = false,
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
    String? employeeBalancesError,
    bool clearEmployeeBalancesError = false,
    String? adminPollsError,
    bool clearAdminPollsError = false,
    String? orderSummaryError,
    bool clearOrderSummaryError = false,
    String? error,
    bool clearError = false,
    String? votingPollId,
    bool clearVoting = false,
    bool? orderSummaryLoading,
  }) {
    return LunchState(
      status: status ?? this.status,
      todayPolls: todayPolls ?? this.todayPolls,
      selectedPollId: clearSelectedPollId
          ? null
          : (selectedPollId ?? this.selectedPollId),
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
      employeeBalancesError: clearEmployeeBalancesError
          ? null
          : (employeeBalancesError ?? this.employeeBalancesError),
      adminPollsError: clearAdminPollsError
          ? null
          : (adminPollsError ?? this.adminPollsError),
      orderSummaryError: clearOrderSummaryError
          ? null
          : (orderSummaryError ?? this.orderSummaryError),
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
  int _todayPollsRequestId = 0;
  int _orderSummaryRequestId = 0;
  int _voteHistoryRequestId = 0;
  Future<void>? _bootstrapInFlight;
  bool _todayPollsStale = false;
  /// Bumped on [clear] so in-flight vote/load cannot rewrite after logout.
  int _sessionGen = 0;
  /// End times set by local admin update/reopen until the server list agrees.
  final Map<String, String> _pinnedPollEndTimes = {};

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

  void _pinPollEndTime(String pollId, String? endTime) {
    final id = pollId.trim();
    final end = endTime?.trim() ?? '';
    if (id.isEmpty || end.isEmpty) return;
    _pinnedPollEndTimes[id] = end.contains('AM') || end.contains('PM')
        ? lunchEndTimeToApi(end)
        : end;
  }

  LunchPoll _withPinnedEnd(LunchPoll poll) {
    final pinned = _pinnedPollEndTimes[poll.id];
    if (pinned == null) return poll;
    final server = poll.endTime?.trim() ?? '';
    final serverApi = server.isEmpty
        ? ''
        : (server.contains('AM') || server.contains('PM')
            ? lunchEndTimeToApi(server)
            : server);
    if (serverApi == pinned) {
      _pinnedPollEndTimes.remove(poll.id);
      return poll;
    }
    return LunchPoll(
      id: poll.id,
      title: poll.title,
      date: poll.date,
      createdAt: poll.createdAt,
      costAmount: poll.costAmount,
      allowVoteChange: poll.allowVoteChange,
      endTime: pinned,
      status: poll.status,
      options: poll.options,
      results: poll.results,
      myVote: poll.myVote,
      reportedTotalVotes: poll.reportedTotalVotes,
    );
  }

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
    final incoming = _withPinnedEnd(poll);
    final merged = prior?.applyServerSnapshot(incoming) ?? incoming;

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
    // Server list is authoritative for membership — do not keep ghost polls.
    final priorById = {for (final p in existing) p.id: p};
    return sortTodayPollsNewestFirst(
      dedupeTodayPolls([
        for (final poll in incoming)
          (priorById[poll.id]?.applyServerSnapshot(_withPinnedEnd(poll)) ??
                  _withPinnedEnd(poll))
              .resolvedForMyLunch(),
      ]),
    );
  }

  List<LunchPoll> _mergePollLists(List<LunchPoll> existing, List<LunchPoll> incoming) {
    final priorById = {for (final p in existing) p.id: p};
    return [
      for (final poll in incoming)
        priorById[poll.id]?.applyServerSnapshot(_withPinnedEnd(poll)) ??
            _withPinnedEnd(poll),
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

  Future<bool> _refreshPollInState(
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
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Refresh one poll before showing its voter breakdown.
  Future<bool> refreshPollVotes(String pollId) =>
      _refreshPollInState(pollId);

  String? get _currentUserId => _ref.read(currentUserIdProvider);

  Future<void> bootstrapUser({bool force = false}) async {
    if (_bootstrapInFlight != null) {
      await _bootstrapInFlight;
      if (!force) return;
    }
    if (!force) {
      if (state.status == LunchLoadStatus.loaded &&
          state.todayPolls.isNotEmpty &&
          !_todayPollsStale) {
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
    final requestId = ++_todayPollsRequestId;
    try {
      final polls = await _repo.getTodayPollsHydrated(
        currentUserId: _currentUserId,
      );
      if (requestId != _todayPollsRequestId) return;
      state = state.copyWith(
        status: LunchLoadStatus.loaded,
        todayPolls: _mergeTodayPollLists(state.todayPolls, polls),
        selectedPollId: state.selectedPollId ??
            (polls.isNotEmpty ? polls.first.id : null),
      );
      _todayPollsStale = false;
    } catch (e) {
      if (requestId != _todayPollsRequestId) return;
      state = state.copyWith(status: LunchLoadStatus.error, error: e.toString());
    }
  }

  Future<void> loadTodayPolls({bool silent = false}) async {
    final requestId = ++_todayPollsRequestId;
    if (!silent) {
      state = state.copyWith(status: LunchLoadStatus.loading, clearError: true);
    }
    try {
      final polls = await _repo.getTodayPollsHydrated(
        currentUserId: _currentUserId,
      );
      if (requestId != _todayPollsRequestId) return;
      _todayPollsStale = false;
      state = state.copyWith(
        status: LunchLoadStatus.loaded,
        todayPolls: _mergeTodayPollLists(state.todayPolls, polls),
        selectedPollId: state.selectedPollId ??
            (polls.isNotEmpty ? polls.first.id : null),
      );
    } catch (e) {
      if (requestId != _todayPollsRequestId) return;
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
    // Ignore duplicate taps on the same in-flight poll; other polls may still vote.
    if (state.votingPollId == pollId) return;

    LunchPoll? target;
    for (final p in state.todayPolls) {
      if (p.id == pollId) {
        target = p;
        break;
      }
    }
    // Pass pre-optimistic poll so prior-day change guards still work.
    final voteGuardPoll = target;
    final sessionGen = _sessionGen;

    state = state.copyWith(votingPollId: pollId, clearError: true);
    final previousToday = state.todayPolls;
    final voteToken = pollId;
    final optimisticPoll = target?.withMyVote(optionId);
    state = state.copyWith(
      todayPolls: [
        for (final p in state.todayPolls)
          if (p.id == pollId) (optimisticPoll ?? p.withMyVote(optionId)) else p,
      ],
    );
    try {
      await _repo.castVote(
        pollId,
        optionId,
        poll: voteGuardPoll,
      );
      if (sessionGen != _sessionGen) return;
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
        if (sessionGen != _sessionGen) return;

        var merged = LunchPoll.mergeAfterVote(local: existing, server: refreshed);
        _upsertPoll(merged);
        final month = state.myBalanceMonth ?? _monthKeyFrom(DateTime.now());
        unawaited(loadMyBalance(month: month, silent: true));
      } catch (_) {
        // Keep optimistic state if refresh fails.
      }
    } catch (e) {
      if (sessionGen != _sessionGen) return;
      // Restore prior vote on the current in-state poll so concurrent refreshes
      // (counts/status) are kept. Only adjust counts when they still match our
      // optimistic snapshot — otherwise force myVote only.
      if (state.votingPollId == voteToken) {
        LunchPoll? previousPoll;
        for (final p in previousToday) {
          if (p.id == pollId) {
            previousPoll = p;
            break;
          }
        }
        state = state.copyWith(
          todayPolls: [
            for (final p in state.todayPolls)
              if (p.id == pollId && previousPoll != null)
                p.restoreMyVote(
                  previousPoll.myVote,
                  adjustCounts: optimisticPoll != null &&
                      p.hasSameOptionCounts(optimisticPoll),
                )
              else
                p,
          ],
          error: e.toString(),
        );
      } else {
        state = state.copyWith(error: e.toString());
      }
    } finally {
      if (sessionGen == _sessionGen && state.votingPollId == voteToken) {
        state = state.copyWith(clearVoting: true);
      }
    }
  }

  /// Loads today's (or recent) poll summary without flashing partial UI.
  Future<void> bootstrapOrderSummary() async {
    state = state.copyWith(
      orderSummaryLoading: true,
      clearOrderSummaryError: true,
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
        orderSummaryError: e.toString(),
        orderSummaryLoading: false,
      );
    }
  }

  Future<void> loadOrderSummary(String pollId, {bool silent = false}) async {
    final requestId = ++_orderSummaryRequestId;
    final keepSummary =
        silent && state.selectedPollId == pollId && state.orderSummary != null;
    state = state.copyWith(
      selectedPollId: pollId,
      clearOrderSummaryError: true,
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
      if (requestId != _orderSummaryRequestId) return;
      final summary = await _repo.getPollSummary(pollId, poll: poll);
      if (requestId != _orderSummaryRequestId) return;
      _upsertPoll(summary.poll);
      state = state.copyWith(
        orderSummary: summary,
        selectedPollId: pollId,
        orderSummaryLoading: false,
        clearOrderSummaryError: true,
      );
    } catch (e) {
      if (requestId != _orderSummaryRequestId) return;
      state = state.copyWith(
        orderSummaryError: e.toString(),
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
        clearAdminPollsError: true,
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
      state = state.copyWith(adminPollsError: e.toString());
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

  Future<void> loadSettings({bool silent = false}) async {
    try {
      final settings = await _repo.getSettings();
      state = state.copyWith(settings: settings, clearError: true);
    } catch (e) {
      // Background loads must not pollute shared My Lunch error snackbars.
      if (silent) return;
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> saveSettings(LunchSettings settings) async {
    // Do not flip shared LunchLoadStatus — My Lunch uses it for poll load UX.
    final saved = await _repo.updateSettings(settings);
    state = state.copyWith(settings: saved, clearError: true);
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
    final priorBalance = state.myBalance;
    final priorMonth = state.myBalanceMonth;
    final priorTx = state.transactions;

    state = state.copyWith(
      myBalanceLoading: !keepExisting,
      myBalanceMonth: monthKey,
      clearMyBalance: !keepExisting,
      clearError: !silent,
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
        myBalance: bal,
        myBalanceMonth: monthKey,
        myBalanceLoading: false,
        transactions: tx,
      );
    } catch (e) {
      if (requestId != _balanceRequestId) return;
      // Always restore prior snapshot on failure so pull-to-refresh doesn't wipe
      // a good balance into "unavailable". Never set shared LunchLoadStatus.
      state = state.copyWith(
        myBalanceLoading: false,
        myBalance: keepExisting ? state.myBalance : priorBalance,
        myBalanceMonth: keepExisting ? monthKey : priorMonth,
        transactions: keepExisting ? state.transactions : priorTx,
        error: silent ? state.error : e.toString(),
      );
    }
  }

  Future<void> loadVoteHistory({
    required DateTime from,
    required DateTime to,
    String? optionType,
  }) async {
    final requestId = ++_voteHistoryRequestId;
    state = state.copyWith(
      voteHistoryLoading: true,
      clearVoteHistoryError: true,
      voteHistory: const [],
    );
    try {
      final rows = await _repo.getVoteHistory(
        from: from,
        to: to,
        optionType: optionType,
      );
      if (requestId != _voteHistoryRequestId) return;
      state = state.copyWith(
        voteHistoryLoading: false,
        voteHistory: rows,
      );
    } catch (e) {
      if (requestId != _voteHistoryRequestId) return;
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
      clearEmployeeBalancesError: true,
    );
    try {
      final rows = await _repo.getEmployeeBalances(from: fromDate, to: toDate);
      if (requestId != _employeeBalancesRequestId) return;
      state = state.copyWith(
        employeeBalances: rows,
        employeeBalancesLoading: false,
        employeeBalancesFrom: _dateKey(fromDate),
        employeeBalancesTo: _dateKey(toDate),
        clearEmployeeBalancesError: true,
      );
    } catch (e) {
      if (requestId != _employeeBalancesRequestId) return;
      state = state.copyWith(
        employeeBalancesLoading: false,
        employeeBalancesFrom: _dateKey(fromDate),
        employeeBalancesTo: _dateKey(toDate),
        employeeBalancesError: e.toString(),
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
    if (endApi != null && endApi.isNotEmpty) {
      _pinPollEndTime(pollId, endApi);
    }
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
      _upsertPoll(
        LunchPoll(
          id: updated.id,
          title: updated.title,
          date: updated.date,
          createdAt: updated.createdAt,
          costAmount: updated.costAmount,
          allowVoteChange:
              poll.isPriorDayPoll ? false : updated.allowVoteChange,
          endTime: endApi,
          status: updated.status.isNotEmpty ? updated.status : 'active',
          options: updated.options,
          results: updated.results,
          myVote: updated.myVote,
          reportedTotalVotes: updated.reportedTotalVotes,
        ),
      );
      unawaited(_ensurePollVisibleOnMyLunch(pollId, endTime: endApi));
    } else {
      // Force saved endTime before merge — otherwise preferPollEndTime keeps a
      // still-viable local deadline over an authoritative past server end
      // (e.g. admin shortens the poll closed time).
      var toUpsert = updated;
      if (endApi != null && endApi.isNotEmpty) {
        toUpsert = LunchPoll(
          id: updated.id,
          title: updated.title,
          date: updated.date,
          createdAt: updated.createdAt,
          costAmount: updated.costAmount,
          allowVoteChange:
              poll.isPriorDayPoll ? false : updated.allowVoteChange,
          endTime: endApi,
          status: updated.status,
          options: updated.options,
          results: updated.results,
          myVote: updated.myVote,
          reportedTotalVotes: updated.reportedTotalVotes,
        );
        _patchPollStatus(
          pollId,
          toUpsert.status.isNotEmpty ? toUpsert.status : 'active',
          endTime: endApi,
          allowVoteChange:
              poll.isPriorDayPoll ? false : poll.allowVoteChange,
        );
      }
      _upsertPoll(toUpsert);
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
    _pinnedPollEndTimes.remove(pollId);
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
    final nextSelected = wasSelected
        ? (today.isNotEmpty
            ? today.first.id
            : (admin.isNotEmpty ? admin.first.id : null))
        : null;
    state = state.copyWith(
      todayPolls: today,
      adminPolls: admin,
      clearSummary: wasSelected,
      selectedPollId: nextSelected,
      clearSelectedPollId: wasSelected && nextSelected == null,
      clearOrderSummaryError: wasSelected && nextSelected == null,
      clearError: true,
    );
    await loadTodayPolls(silent: true);
    if (!wasSelected) return;
    final selected = state.selectedPollId;
    if (selected != null && selected.isNotEmpty) {
      await loadOrderSummary(selected, silent: true);
    } else {
      state = state.copyWith(
        clearSummary: true,
        clearOrderSummaryError: true,
        clearSelectedPollId: true,
      );
    }
  }

  void clearError() => state = state.copyWith(clearError: true);

  void clear() {
    _pinnedPollEndTimes.clear();
    _bootstrapInFlight = null;
    _sessionGen++;
    _balanceRequestId++;
    _employeeBalancesRequestId++;
    _adminPollsRequestId++;
    _todayPollsRequestId++;
    _orderSummaryRequestId++;
    _voteHistoryRequestId++;
    _todayPollsStale = false;
    state = const LunchState();
  }
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
