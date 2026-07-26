import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/lunch_poll_schedule.dart';
import '../models/lunch_model.dart';

class LunchRepository {
  LunchRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  static String _dateOnly(DateTime d) {
    final l = d.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
  }

  static List<Map<String, dynamic>> _asMapList(dynamic raw, [List<String> keys = const []]) {
    if (raw is List) {
      return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (raw is Map) {
      for (final k in keys) {
        final inner = raw[k];
        if (inner is List) {
          return inner
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    }
    return [];
  }

  Future<LunchSettings> getSettings() async {
    final response = await _api.get(AppConstants.lunchSettings);
    return LunchSettings.fromJson(_asMap(response.data));
  }

  Future<LunchSettings> updateSettings(LunchSettings settings) async {
    final response = await _api.put(
      AppConstants.lunchSettings,
      data: settings.toJson(),
    );
    return LunchSettings.fromJson(_asMap(response.data));
  }

  Future<LunchDashboardStats> getDashboard() async {
    final response = await _api.get(AppConstants.lunchDashboard);
    return LunchDashboardStats.fromJson(response.data);
  }

  Future<LunchTodayBundle> getTodayPolls() async {
    final response = await _api.get(AppConstants.lunchPollsToday);
    return LunchTodayBundle.fromJson(response.data);
  }

  /// Walks the `/polls/today` payload for poll-shaped maps the bundle parser missed.
  List<LunchPoll> _extractPollsFromTodayRaw(dynamic raw) {
    final found = <String, LunchPoll>{};
    void walk(dynamic node) {
      if (node is Map) {
        final map = Map<String, dynamic>.from(node);
        final id = (map['id'] ?? map['_id'])?.toString().trim() ?? '';
        final title = (map['title'] ?? map['name'] ?? '').toString().trim();
        final status = (map['status'] ?? '').toString().trim();
        if (id.isNotEmpty && title.isNotEmpty && status.isNotEmpty) {
          try {
            final poll = LunchPoll.fromJson(map).resolvedForMyLunch();
            if (poll.showOnMyLunch) found[poll.id] = poll;
          } catch (_) {}
        }
        for (final value in map.values) {
          walk(value);
        }
      } else if (node is List) {
        for (final value in node) {
          walk(value);
        }
      }
    }

    walk(raw);
    return found.values.toList();
  }

  Future<List<LunchPoll>> getTodayPollsHydrated({String? currentUserId}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final todayResponse = await _api.get(AppConstants.lunchPollsToday);
    final bundle = LunchTodayBundle.fromJson(todayResponse.data);

    final byId = <String, LunchPoll>{};
    void upsertRaw(LunchPoll poll) {
      if (poll.id.isEmpty) return;
      _upsertTodayPollById(byId, poll.resolvedForMyLunch().withoutMyVote());
    }

    for (final poll in bundle.items) {
      upsertRaw(poll);
    }
    final legacy = bundle.legacyPoll;
    if (legacy != null && legacy.id.isNotEmpty) {
      upsertRaw(legacy);
    }
    for (final poll in _extractPollsFromTodayRaw(todayResponse.data)) {
      upsertRaw(poll);
    }

    // Admin list endpoints may 403 for regular users — never block /today.
    // One recent-active window is enough to find reactivated polls; /today
    // already covers the current day (avoid 3× listPolls fan-out).
    try {
      final recentActive = await listPolls(
        from: today.subtract(const Duration(days: 60)),
        to: today,
        status: 'active',
      );
      for (final poll in recentActive) {
        final resolved = poll.resolvedForMyLunch();
        if (resolved.showOnMyLunch) {
          _upsertTodayPollById(byId, resolved.withoutMyVote());
        }
      }
    } catch (_) {}

    await _enrichOpenPollsForMyLunch(
      byId: byId,
      today: today,
      currentUserId: currentUserId,
      seedPollIds: byId.keys,
    );

    var polls = sortTodayPollsNewestFirst(
      byId.values
          .map((p) => p.resolvedForMyLunch())
          .where((p) => p.appearsOnMyLunchCard)
          .toList(),
    );
    if (polls.isEmpty) return polls;

    if (!_pollNeedsHydration(polls)) {
      return sortTodayPollsNewestFirst(
        dedupeTodayPolls(
          polls.map((p) => p.withPollScopedVotes()).toList(),
        ),
      );
    }

    final historyRange = _voteHistoryRangeForPolls(polls, today);
    var historyVotes = const <LunchVoteHistoryRow>[];
    if (polls.any((p) => p.scopedMyVote == null)) {
      try {
        historyVotes = await getVoteHistory(
          from: historyRange.$1,
          to: historyRange.$2,
          userId: currentUserId,
        );
      } catch (_) {}
      if (historyVotes.isEmpty && currentUserId != null && currentUserId.isNotEmpty) {
        try {
          final all = await getVoteHistory(
            from: historyRange.$1,
            to: historyRange.$2,
            userId: 'all',
          );
          historyVotes = all
              .where((r) => r.userId != null && r.userId == currentUserId)
              .toList();
        } catch (_) {}
      }
    }

    final hydrated = await Future.wait(
      polls.map(
        (poll) => _hydratePollForTodayFast(
          poll,
          historyVotes: historyVotes,
          currentUserId: currentUserId,
        ),
      ),
    );
    return sortTodayPollsNewestFirst(dedupeTodayPolls(hydrated));
  }

  static bool _pollNeedsHydration(List<LunchPoll> polls) {
    return polls.any((p) {
      if (p.id.isEmpty || p.mergedOptions.isEmpty) return true;
      if (p.scopedMyVote == null) return true;
      if (!p.hasPerOptionVotes &&
          (p.reportedTotalVotes ?? 0) <= 0 &&
          p.totalVoteCount <= 0) {
        return true;
      }
      return false;
    });
  }

  static (DateTime, DateTime) _voteHistoryRangeForPolls(
    List<LunchPoll> polls,
    DateTime today,
  ) {
    var from = today;
    for (final poll in polls) {
      final d = poll.date;
      if (d == null) continue;
      final day = DateTime(d.year, d.month, d.day);
      if (day.isBefore(from)) from = day;
    }
    final floor = today.subtract(const Duration(days: 90));
    if (from.isBefore(floor)) from = floor;
    return (from, today);
  }

  Future<LunchPoll> _hydratePollForTodayFast(
    LunchPoll poll, {
    List<LunchVoteHistoryRow> historyVotes = const [],
    String? currentUserId,
  }) async {
    var hydrated = poll.withPollScopedVotes();
    if (hydrated.mergedOptions.isEmpty && hydrated.id.isNotEmpty) {
      hydrated = await _hydratePoll(hydrated);
    }

    // Prefer authoritative poll payload over history guessing.
    if (hydrated.id.isNotEmpty &&
        (hydrated.scopedMyVote == null ||
            hydrated.mergedOptions.isEmpty ||
            !hydrated.hasPerOptionVotes ||
            hydrated.totalVoteCount <= 0)) {
      final needsFull =
          hydrated.scopedMyVote == null || hydrated.mergedOptions.isEmpty;
      final needsSummary =
          !hydrated.hasPerOptionVotes || hydrated.totalVoteCount <= 0;
      try {
        if (needsFull && needsSummary) {
          final results = await Future.wait<Object?>([
            getPoll(hydrated.id),
            getPollSummary(hydrated.id, poll: hydrated, fetchPoll: false),
          ]);
          final full = results[0] as LunchPoll;
          final summary = results[1] as LunchOrderSummary;
          hydrated = hydrated.applyServerSnapshot(full);
          hydrated = hydrated
              .applyServerSnapshot(summary.poll)
              .withVoteSummary(
            breakdown: summary.menuBreakdown,
            totalVotes: summary.totalVotes,
          );
        } else if (needsFull) {
          final full = await getPoll(hydrated.id);
          hydrated = hydrated.applyServerSnapshot(full);
        } else if (needsSummary) {
          final summary = await getPollSummary(hydrated.id, poll: hydrated);
          hydrated = hydrated
              .applyServerSnapshot(summary.poll)
              .withVoteSummary(
            breakdown: summary.menuBreakdown,
            totalVotes: summary.totalVotes,
          );
        }
      } catch (_) {}
    }

    // History is last resort only when the server did not provide myVote.
    if (hydrated.scopedMyVote == null && historyVotes.isNotEmpty) {
      final fromHistory = _myVoteFromHistory(
        hydrated.id,
        hydrated,
        historyVotes,
        currentUserId: currentUserId,
      );
      if (fromHistory != null) {
        return LunchPoll(
          id: hydrated.id,
          title: hydrated.title,
          date: hydrated.date,
          createdAt: hydrated.createdAt,
          costAmount: hydrated.costAmount,
          allowVoteChange: hydrated.allowVoteChange,
          endTime: hydrated.endTime,
          status: hydrated.status,
          options: hydrated.options,
          results: hydrated.results,
          myVote: fromHistory,
          reportedTotalVotes: hydrated.reportedTotalVotes,
        ).withPollScopedVotes();
      }
    }

    return hydrated.withPollScopedVotes();
  }

  LunchMyVote? _myVoteFromHistory(
    String pollId,
    LunchPoll poll,
    List<LunchVoteHistoryRow> rows, {
    String? currentUserId,
  }) {
    // Require a known current user — never attach anonymous/other rows as mine.
    if (currentUserId == null || currentUserId.isEmpty) return null;

    LunchVoteHistoryRow? bestRow;
    DateTime? bestAt;

    for (final row in rows) {
      if (row.pollId != pollId) continue;
      if (row.userId == null ||
          row.userId!.isEmpty ||
          row.userId != currentUserId) {
        continue;
      }
      final at = row.votedAt;
      if (bestRow == null ||
          (at != null && (bestAt == null || at.isAfter(bestAt)))) {
        bestRow = row;
        bestAt = at;
      }
    }

    if (bestRow == null) return null;
    return LunchPoll.myVoteFromHistoryRow(
      bestRow,
      poll.mergedOptions,
      votedAt: bestRow.votedAt,
    );
  }

  static (DateTime from, DateTime to) _myVoteHistoryRange(LunchPoll poll) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final pollDate = poll.date ?? today;
    final pollDay = DateTime(pollDate.year, pollDate.month, pollDate.day);
    final from = pollDay.isBefore(today) ? pollDay : today;
    return (from, today);
  }

  static void _upsertTodayPollById(Map<String, LunchPoll> byId, LunchPoll poll) {
    if (poll.id.isEmpty) return;
    final existing = byId[poll.id];
    byId[poll.id] = existing == null
        ? poll.withPollScopedVotes()
        : existing.applyServerSnapshot(poll).withPollScopedVotes();
  }

  /// Discover and refresh open polls for My Lunch (works for non-admins too).
  Future<void> _enrichOpenPollsForMyLunch({
    required Map<String, LunchPoll> byId,
    required DateTime today,
    String? currentUserId,
    Iterable<String> seedPollIds = const [],
  }) async {
    final candidateIds = <String>{...seedPollIds};

    for (final poll in byId.values) {
      if (poll.id.isEmpty) continue;
      final resolved = poll.resolvedForMyLunch();
      if (resolved.showOnMyLunch) candidateIds.add(poll.id);
    }

    // Vote history for myVote is loaded once in getTodayPollsHydrated — do not
    // duplicate a 60-day history fetch here just for id discovery.
    for (final id in await _pollIdsFromRecentNotifications()) {
      candidateIds.add(id);
    }

    if (candidateIds.isEmpty) return;

    // Only fetch polls we do not already have (or that lack options).
    final missing = candidateIds.where((id) {
      final existing = byId[id];
      return existing == null || existing.mergedOptions.isEmpty;
    }).toList();
    if (missing.isEmpty) return;

    final ids = missing.length > 20 ? missing.take(20).toList() : missing;

    final fetched = await Future.wait<LunchPoll?>(
      ids.map((id) async {
        try {
          return await getPoll(id);
        } catch (_) {
          return byId[id];
        }
      }),
    );

    for (final poll in fetched) {
      if (poll == null || poll.id.isEmpty) continue;
      final resolved = poll.resolvedForMyLunch();
      if (resolved.showOnMyLunch) {
        _upsertTodayPollById(byId, resolved.withoutMyVote());
      }
    }
  }

  Future<Set<String>> _pollIdsFromRecentNotifications() async {
    try {
      final response = await _api.get(
        AppConstants.notifications,
        queryParameters: const {'limit': '50', 'offset': '0'},
      );
      final items = _asMapList(
        response.data,
        const ['items', 'notifications', 'data'],
      );
      final ids = <String>{};
      for (final item in items) {
        _collectPollIdsFromNotification(item, ids);
      }
      return ids;
    } catch (_) {
      return {};
    }
  }

  void _collectPollIdsFromNotification(
    Map<String, dynamic> json,
    Set<String> out,
  ) {
    // Only explicit poll keys / poll URLs — bare entityId matches any module.
    for (final key in const ['pollId', 'poll_id']) {
      final v = json[key]?.toString().trim();
      if (v != null && v.isNotEmpty) out.add(v);
    }

    for (final value in json.values) {
      if (value is String && value.contains('/polls/')) {
        final match = RegExp(r'/polls/([a-fA-F0-9]{24})').firstMatch(value);
        if (match != null) out.add(match.group(1)!);
      }
    }

    for (final metaKey in const ['metadata', 'data', 'payload', 'extra']) {
      final nested = json[metaKey];
      if (nested is Map) {
        _collectPollIdsFromNotification(
          Map<String, dynamic>.from(nested),
          out,
        );
      }
    }
  }

  Future<LunchPoll> _hydratePoll(LunchPoll poll) async {
    if (poll.id.isEmpty) return poll.withPollScopedVotes();
    try {
      final full = await getPoll(poll.id);
      return poll.applyServerSnapshot(full).withPollScopedVotes();
    } catch (_) {
      return poll.withPollScopedVotes();
    }
  }

  Future<List<LunchPoll>> listPollsHydrated({
    DateTime? from,
    DateTime? to,
    String? status,
    String? currentUserId,
    bool includeMyVote = true,
  }) async {
    final polls = await listPolls(from: from, to: to, status: status);
    if (polls.isEmpty) return polls;
    return Future.wait(
      polls.map(
        (poll) => includeMyVote
            ? _hydratePollWithVoteTotal(
                poll,
                currentUserId: currentUserId,
              )
            : _hydratePollForAdminList(poll),
      ),
    );
  }

  /// Admin list — vote totals only, no per-user vote history N+1.
  Future<LunchPoll> _hydratePollForAdminList(LunchPoll poll) async {
    var hydrated = poll.mergedOptions.isEmpty && poll.id.isNotEmpty
        ? await _hydratePoll(poll)
        : poll;
    if (hydrated.id.isEmpty) return hydrated.withoutMyVote();

    if (hydrated.hasPerOptionVotes && hydrated.totalVoteCount > 0) {
      return hydrated.withoutMyVote();
    }

    try {
      final summary = await getPollSummary(hydrated.id, poll: hydrated);
      hydrated = hydrated
          .applyServerSnapshot(summary.poll)
          .withVoteSummary(
        breakdown: summary.menuBreakdown,
        totalVotes: summary.totalVotes,
      );
    } catch (_) {}

    return hydrated.withoutMyVote();
  }

  Future<LunchPoll> _hydratePollWithVoteTotal(
    LunchPoll poll, {
    String? currentUserId,
    bool forceSummary = false,
  }) async {
    var hydrated = poll.mergedOptions.isEmpty && poll.id.isNotEmpty
        ? await _hydratePoll(poll)
        : poll.withPollScopedVotes();
    if (hydrated.id.isEmpty) return hydrated;

    final hasCounts =
        hydrated.hasPerOptionVotes && hydrated.totalVoteCount > 0;
    final needsVoters = !hydrated.mergedOptions.any((o) => o.voters.isNotEmpty);
    if (!hasCounts || forceSummary || needsVoters) {
      try {
        final summary = await getPollSummary(hydrated.id, poll: hydrated);
        hydrated = hydrated
            .applyServerSnapshot(summary.poll)
            .withVoteSummary(
              breakdown: summary.menuBreakdown,
              totalVotes: summary.totalVotes,
            )
            .attachEmployeeVotes(summary.employeeVotes);
      } catch (_) {}
    }

    LunchMyVote? myVote = hydrated.scopedMyVote;
    if (myVote == null) {
      try {
        final full = await getPoll(hydrated.id);
        hydrated = hydrated.applyServerSnapshot(full);
        myVote = hydrated.scopedMyVote;
      } catch (_) {}
    }

    if (myVote == null && currentUserId != null && currentUserId.isNotEmpty) {
      final range = _myVoteHistoryRange(hydrated);
      try {
        var history = await getVoteHistory(
          from: range.$1,
          to: range.$2,
          userId: currentUserId,
        );
        if (history.isEmpty) {
          final all = await getVoteHistory(
            from: range.$1,
            to: range.$2,
            userId: 'all',
          );
          history = all
              .where((r) => r.userId != null && r.userId == currentUserId)
              .toList();
        }
        myVote = _myVoteFromHistory(
          hydrated.id,
          hydrated,
          history,
          currentUserId: currentUserId,
        );
      } catch (_) {}
    }

    if (myVote != null && myVote.optionId != hydrated.scopedMyVote?.optionId) {
      final existing = hydrated.scopedMyVote;
      if (existing != null &&
          hydrated.isReactivatedPoll &&
          _myVoteIsNewer(existing, myVote)) {
        return hydrated.withPollScopedVotes();
      }
      return LunchPoll(
        id: hydrated.id,
        title: hydrated.title,
        date: hydrated.date,
        createdAt: hydrated.createdAt,
        costAmount: hydrated.costAmount,
        allowVoteChange: hydrated.allowVoteChange,
        endTime: hydrated.endTime,
        status: hydrated.status,
        options: hydrated.options,
        results: hydrated.results,
        myVote: myVote,
        reportedTotalVotes: hydrated.reportedTotalVotes,
      ).withPollScopedVotes();
    }

    return hydrated.withPollScopedVotes();
  }

  Future<List<LunchPoll>> listPolls({
    DateTime? from,
    DateTime? to,
    String? status,
  }) async {
    final qp = <String, dynamic>{};
    if (from != null) qp['from'] = _dateOnly(from);
    if (to != null) qp['to'] = _dateOnly(to);
    if (status != null && status.isNotEmpty) qp['status'] = status;
    final response = await _api.get(
      AppConstants.lunchPolls,
      queryParameters: qp.isEmpty ? null : qp,
    );
    return _asMapList(response.data, const ['items', 'polls', 'data'])
        .map(LunchPoll.fromJson)
        .toList();
  }

  /// Lightweight poll list for pickers — one list request + today's bundle, no per-poll hydration.
  Future<List<LunchPoll>> fetchPollPickerList({
    required DateTime from,
    required DateTime to,
  }) async {
    final today = await getTodayPolls();

    List<LunchPoll> listed = [];
    try {
      listed = await listPolls(from: from, to: to);
    } catch (_) {}

    final byId = <String, LunchPoll>{};
    for (final poll in [...today.items, ...listed]) {
      if (poll.id.isNotEmpty) byId[poll.id] = poll;
    }

    final polls = byId.values.toList()
      ..sort((a, b) {
        final ad = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
    return polls;
  }

  Future<LunchPoll> getPoll(String pollId) async {
    final response = await _api.get(AppConstants.lunchPollById(pollId));
    return LunchPoll.fromJson(_unwrapPollMap(response.data));
  }

  Future<LunchPoll> refreshPollHydrated(
    String pollId, {
    String? currentUserId,
  }) async {
    return _hydratePollWithVoteTotal(
      await getPoll(pollId),
      currentUserId: currentUserId,
      forceSummary: true,
    );
  }

  Future<LunchPoll> createPoll(LunchPoll poll) async {
    // Production API uses optionType `office` for menu items — try full create first.
    try {
      return await _createPollDirect(poll);
    } catch (e) {
      if (!_isRetryableCreateError(e) || poll.options.length <= 2) rethrow;
    }
    return _createPollStaged(poll);
  }

  static bool _isRetryableCreateError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('invalid option') || msg.contains('list.count');
  }

  Future<LunchPoll> _createPollDirect(LunchPoll poll) async {
    final response = await _api.post(
      AppConstants.lunchPolls,
      data: poll.toCreateJson(),
    );
    return LunchPoll.fromJson(_unwrapPollMap(response.data));
  }

  Future<LunchPoll> _createPollStaged(LunchPoll poll) async {
    final parts = poll.partitionForCreate();
    final created = await _createPollDirect(poll.withOptions(parts.initial));
    if (parts.extras.isEmpty) return created;

    try {
      return await _appendPollOptions(
        pollId: created.id,
        extras: parts.extras,
      );
    } catch (e) {
      try {
        await deletePoll(created.id);
      } catch (_) {}
      rethrow;
    }
  }

  Future<LunchPoll> _appendPollOptions({
    required String pollId,
    required List<LunchPollOption> extras,
  }) async {
    final current = await getPoll(pollId);
    final merged = LunchPoll(
      id: pollId,
      title: current.title,
      options: [...current.options, ...extras],
    );
    return _putPollOptions(pollId, merged.optionsForPut());
  }

  static List<Map<String, dynamic>> _optionMapsFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Map<String, dynamic> _appendOptionEntry(Map<String, dynamic> raw) {
    final label = raw['label']?.toString() ?? raw['name']?.toString() ?? '';
    final map = <String, dynamic>{
      'label': label,
      'optionType': raw['optionType']?.toString() ?? '',
    };
    if (raw['orderIndex'] != null) {
      map['orderIndex'] = raw['orderIndex'];
    }
    final pollId = raw['pollId']?.toString();
    if (pollId != null && pollId.isNotEmpty) {
      map['pollId'] = pollId;
    }
    final id = raw['id']?.toString();
    if (id != null && id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }

  static List<Map<String, dynamic>> _appendOptionEntries(
    List<Map<String, dynamic>> newOptions,
  ) {
    return [for (final raw in newOptions) _appendOptionEntry(raw)];
  }

  static bool _isRetryableOptionAppendError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('list.count');
  }

  static bool _isBothKeysError(Object error) {
    return error.toString().toLowerCase().contains('cannot send both');
  }

  /// PUT poll options — production shape; refresh and verify new rows persisted.
  Future<LunchPoll> _putPollOptions(
    String pollId,
    List<Map<String, dynamic>> optionMaps,
  ) async {
    if (optionMaps.isEmpty) return getPoll(pollId);

    final entries = _appendOptionEntries(optionMaps);
    Object? lastError;

    Future<LunchPoll> refresh() => refreshPollHydrated(pollId);

    bool persisted(LunchPoll poll) =>
        // Full options PUT is a replace — compare to payload size, not growth.
        poll.options.length >= entries.length;

    try {
      await _putPoll(pollId, {'options': entries});
      final updated = await refresh();
      if (persisted(updated)) return updated;
    } catch (e) {
      lastError = e;
      if (_isBothKeysError(e)) rethrow;
      if (!_isRetryableOptionAppendError(e)) rethrow;
    }

    final existing =
        entries.where((e) => (e['id']?.toString() ?? '').isNotEmpty).toList();
    final newOnes =
        entries.where((e) => (e['id']?.toString() ?? '').isEmpty).toList();
    var merged = existing;
    LunchPoll? latest;
    for (final entry in newOnes) {
      merged = [...merged, entry];
      try {
        await _putPoll(pollId, {'options': merged});
        latest = await refresh();
        if (persisted(latest)) return latest;
        merged = [
          for (var i = 0; i < latest.options.length; i++)
            latest.options[i].toPutJson(orderIndex: i, pollId: pollId),
        ];
      } catch (e) {
        lastError = e;
        if (_isBothKeysError(e)) rethrow;
        if (!_isRetryableOptionAppendError(e)) rethrow;
      }
    }

    if (latest != null && persisted(latest)) return latest;
    throw lastError ?? Exception('Could not update poll options');
  }

  Future<LunchPoll> updatePoll(String pollId, Map<String, dynamic> data) async {
    final payload = Map<String, dynamic>.from(data);
    final optionUpdates = _optionMapsFrom(payload.remove('optionUpdates'));
    final options = _optionMapsFrom(payload.remove('options'));
    final hasMetadata = payload.isNotEmpty;

    if (hasMetadata) {
      await _putPoll(pollId, payload);
    }
    if (options.isNotEmpty) {
      return _putPollOptions(pollId, options);
    }
    if (optionUpdates.isNotEmpty) {
      return _putPoll(pollId, {'optionUpdates': optionUpdates});
    }
    if (hasMetadata) {
      return getPoll(pollId);
    }

    return _putPoll(pollId, data);
  }

  Future<LunchPoll> _putPoll(String pollId, Map<String, dynamic> data) async {
    final response = await _api.put(
      AppConstants.lunchPollById(pollId),
      data: data,
    );
    return LunchPoll.fromJson(_unwrapPollMap(response.data));
  }

  Future<LunchPoll> setPollStatus(String pollId, String status) async {
    final normalized = status.trim().toLowerCase();
    try {
      final response = await _api.patch(
        AppConstants.lunchPollStatus(pollId),
        data: {'status': normalized},
      );
      final parsed = _tryParsePoll(response.data);
      if (parsed != null) return parsed;
    } catch (_) {}

    try {
      final response = await _api.put(
        AppConstants.lunchPollById(pollId),
        data: {'status': normalized},
      );
      final parsed = _tryParsePoll(response.data);
      if (parsed != null) return parsed;
    } catch (_) {}

    return getPoll(pollId);
  }

  /// Reopen a closed poll — backend requires PATCH `/status` (not PUT `status`).
  Future<LunchPoll> reopenPoll(
    String pollId, {
    required String endTimeApi,
    bool allowVoteChange = false,
  }) async {
    final endTime = endTimeApi.trim();
    if (endTime.isEmpty) {
      throw ArgumentError('End time is required to reopen a poll');
    }

    final extendMinutes = lunchExtendMinutesUntil(endTime);

    // 1) Activate — authoritative status endpoint per Postman/API contract.
    var poll = await setPollStatus(pollId, 'active');

    // 2) Extend window — prior-day reopens: no vote changes on server either.
    final payloads = [
      {
        'allowVoteChange': allowVoteChange,
        'allow_vote_change': allowVoteChange,
        'extendMinutes': extendMinutes,
        'endTime': endTime,
        'end_time': endTime,
      },
      {
        'allowVoteChange': allowVoteChange,
        'allow_vote_change': allowVoteChange,
        'extendMinutes': extendMinutes,
      },
      {
        'allowVoteChange': allowVoteChange,
        'allow_vote_change': allowVoteChange,
        'endTime': endTime,
        'end_time': endTime,
      },
    ];

    for (final payload in payloads) {
      try {
        poll = await updatePoll(pollId, payload);
        break;
      } catch (_) {}
    }

    poll = await getPoll(pollId);
    if (poll.status.toLowerCase() != 'active') {
      poll = await setPollStatus(pollId, 'active');
    }

    if (poll.status.toLowerCase() != 'active') {
      throw Exception(
        'Could not reactivate poll on server — status is still ${poll.status}.',
      );
    }

    return LunchPoll(
      id: poll.id,
      title: poll.title,
      date: poll.date,
      createdAt: poll.createdAt,
      costAmount: poll.costAmount,
      allowVoteChange: allowVoteChange,
      endTime: endTime,
      status: 'active',
      options: poll.options,
      results: poll.results,
      myVote: poll.myVote,
      reportedTotalVotes: poll.reportedTotalVotes,
    ).withPollScopedVotes();
  }

  /// Ensures a prior-day/reopened poll accepts votes on the server.
  Future<void> ensurePollOpenForVoting(
    String pollId, {
    LunchPoll? poll,
  }) async {
    await setPollStatus(pollId, 'active');

    final endTime = poll?.endTime?.trim();
    final allowChanges = poll?.isPriorDayPoll == true ? false : true;
    final payload = <String, dynamic>{
      'allowVoteChange': allowChanges,
      'allow_vote_change': allowChanges,
      'extendMinutes': endTime != null && endTime.isNotEmpty
          ? lunchExtendMinutesUntil(endTime)
          : 60,
    };
    if (endTime != null && endTime.isNotEmpty) {
      payload['endTime'] = endTime;
      payload['end_time'] = endTime;
    }

    try {
      await updatePoll(pollId, payload);
    } catch (_) {
      try {
        await updatePoll(pollId, {
          'allowVoteChange': allowChanges,
          'allow_vote_change': allowChanges,
          'extendMinutes': payload['extendMinutes'],
        });
      } catch (_) {}
    }
  }

  LunchPoll? _tryParsePoll(dynamic raw) {
    try {
      final poll = LunchPoll.fromJson(_unwrapPollMap(raw));
      return poll.id.isNotEmpty ? poll : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> deletePoll(String pollId) async {
    await _api.delete(AppConstants.lunchPollById(pollId));
  }

  static bool _myVoteIsNewer(LunchMyVote current, LunchMyVote candidate) {
    final currentAt = current.votedAt;
    final candidateAt = candidate.votedAt;
    if (currentAt == null || candidateAt == null) return false;
    return currentAt.isAfter(candidateAt);
  }

  Future<void> castVote(
    String pollId,
    String optionId, {
    LunchPoll? poll,
  }) async {
    if (poll != null &&
        poll.isPriorDayPoll &&
        poll.scopedMyVote != null &&
        poll.scopedMyVote!.optionId.isNotEmpty &&
        poll.scopedMyVote!.optionId != optionId) {
      throw Exception('Vote changes are not allowed on reopened polls.');
    }

    try {
      await _postVote(pollId, optionId);
      return;
    } catch (e) {
      // Only retry-open for reactivated/prior-day polls that should accept votes.
      // Never reopen an intentionally closed or past-deadline poll as a side-effect.
      if (poll == null ||
          poll.isCancelled ||
          poll.status.toLowerCase() == 'closed' ||
          lunchPollIsPastEndTime(
            endTime: poll.endTime,
            pollDate: poll.date,
            status: poll.status,
          ) ||
          !(poll.isPriorDayPoll || poll.isReactivatedPoll)) {
        rethrow;
      }
    }

    await ensurePollOpenForVoting(pollId, poll: poll);
    await _postVote(pollId, optionId);
  }

  Future<void> _postVote(String pollId, String optionId) async {
    await _api.post(
      AppConstants.lunchPollVote(pollId),
      data: {'optionId': optionId},
    );
  }

  Future<LunchOrderSummary> getPollSummary(
    String pollId, {
    LunchPoll? poll,
    bool fetchPoll = true,
  }) async {
    final response = await _api.get(AppConstants.lunchPollSummary(pollId));
    LunchPoll? enriched = poll;
    final alreadyRich =
        poll != null && poll.id.isNotEmpty && poll.mergedOptions.isNotEmpty;
    if (fetchPoll && !alreadyRich) {
      try {
        final full = await getPoll(pollId);
        enriched = (enriched ?? full).applyServerSnapshot(full);
      } catch (_) {
        enriched = poll;
      }
    }
    var summary = LunchOrderSummary.fromJson(response.data, pollFallback: enriched);
    if (summary.employeeVotes.isEmpty) {
      var derived = enriched != null
          ? LunchOrderSummary.deriveEmployeeVotes(enriched)
          : <LunchEmployeeVoteRow>[];
      if (derived.isEmpty && summary.menuBreakdown.isNotEmpty) {
        derived = LunchOrderSummary.deriveEmployeeVotesFromBreakdown(summary.menuBreakdown);
      }
      if (derived.isEmpty) {
        final pollDate = summary.poll.date ?? enriched?.date;
        if (pollDate != null) {
          derived = await _employeeVotesFromHistory(pollDate, pollId);
        }
      }
      if (derived.isNotEmpty) {
        summary = LunchOrderSummary(
          poll: summary.poll.id.isNotEmpty ? summary.poll : (enriched ?? summary.poll),
          officeOrders: summary.officeOrders,
          personalCount: summary.personalCount,
          totalVotes: summary.totalVotes,
          menuBreakdown: summary.menuBreakdown,
          employeeVotes: derived,
        );
      }
    }
    final pollDate = summary.poll.date ?? enriched?.date;
    if (pollDate != null && summary.employeeVotes.any((v) => v.votedAt == null)) {
      final withTimes = await _enrichEmployeeVoteTimes(
        summary.employeeVotes,
        pollDate,
        pollId,
      );
      summary = LunchOrderSummary(
        poll: summary.poll,
        officeOrders: summary.officeOrders,
        personalCount: summary.personalCount,
        totalVotes: summary.totalVotes,
        menuBreakdown: summary.menuBreakdown,
        employeeVotes: withTimes,
      );
    }
    var canonical = enriched != null
        ? enriched.applyServerSnapshot(summary.poll)
        : summary.poll;
    canonical = canonical
        .withVoteSummary(
          breakdown: summary.menuBreakdown,
          totalVotes: summary.totalVotes,
        )
        .attachEmployeeVotes(summary.employeeVotes);
    return LunchOrderSummary(
      poll: canonical,
      officeOrders: summary.officeOrders,
      personalCount: summary.personalCount,
      totalVotes: summary.totalVotes,
      menuBreakdown: summary.menuBreakdown,
      employeeVotes: summary.employeeVotes,
    );
  }

  Future<List<LunchEmployeeVoteRow>> _enrichEmployeeVoteTimes(
    List<LunchEmployeeVoteRow> votes,
    DateTime date,
    String pollId,
  ) async {
    try {
      final rows = await getVoteHistory(from: date, to: date, userId: 'all');
      final history = LunchOrderSummary.fromVoteHistoryRows(rows, pollId: pollId);
      if (history.isEmpty) return votes;

      LunchEmployeeVoteRow match(LunchEmployeeVoteRow vote) {
        for (final h in history) {
          final sameUser = vote.userId.isNotEmpty &&
              h.userId.isNotEmpty &&
              vote.userId == h.userId;
          final sameName = vote.userName.toLowerCase() == h.userName.toLowerCase();
          if ((sameUser || sameName) && h.votedAt != null) {
            return LunchEmployeeVoteRow(
              userId: vote.userId,
              userName: vote.userName,
              choice: vote.choice.isNotEmpty ? vote.choice : h.choice,
              optionType: vote.optionType.isNotEmpty ? vote.optionType : h.optionType,
              votedAt: h.votedAt,
            );
          }
        }
        return vote;
      }

      return votes.map(match).toList();
    } catch (_) {
      return votes;
    }
  }

  Future<List<LunchEmployeeVoteRow>> _employeeVotesFromHistory(
    DateTime date,
    String pollId,
  ) async {
    try {
      final rows = await getVoteHistory(from: date, to: date, userId: 'all');
      return LunchOrderSummary.fromVoteHistoryRows(rows, pollId: pollId);
    } catch (_) {
      return const [];
    }
  }

  Future<List<LunchVoteHistoryRow>> getVoteHistory({
    required DateTime from,
    required DateTime to,
    String? optionType,
    String? userId,
  }) async {
    final qp = <String, dynamic>{
      'from': _dateOnly(from),
      'to': _dateOnly(to),
    };
    if (optionType != null && optionType.isNotEmpty) {
      qp['optionType'] = optionType;
    }
    if (userId != null && userId.isNotEmpty) qp['userId'] = userId;
    final response = await _api.get(
      AppConstants.lunchVotesHistory,
      queryParameters: qp,
    );
    return _asMapList(response.data, const ['items', 'history', 'data', 'votes'])
        .map(LunchVoteHistoryRow.fromJson)
        .toList();
  }

  Future<LunchBalanceMe> getMyBalance({String? month}) async {
    final response = await _api.get(
      AppConstants.lunchBalanceMe,
      queryParameters: month == null ? null : {'month': month},
    );
    return LunchBalanceMe.fromJson(response.data);
  }

  Future<List<LunchBalanceTransaction>> getBalanceTransactions({
    String? userId,
    DateTime? from,
    DateTime? to,
  }) async {
    final qp = <String, dynamic>{};
    if (userId != null && userId.isNotEmpty) qp['userId'] = userId;
    if (from != null) qp['from'] = _dateOnly(from);
    if (to != null) qp['to'] = _dateOnly(to);
    final response = await _api.get(
      AppConstants.lunchBalanceTransactions,
      queryParameters: qp.isEmpty ? null : qp,
    );
    return _asMapList(response.data, const ['items', 'transactions', 'data'])
        .map(LunchBalanceTransaction.fromJson)
        .toList();
  }

  Future<List<LunchEmployeeBalance>> getEmployeeBalances({
    required DateTime from,
    required DateTime to,
  }) async {
    final fromKey = _dateOnly(from);
    final toKey = _dateOnly(to);
    final response = await _api.get(
      AppConstants.lunchBalanceEmployees,
      queryParameters: {
        'from': fromKey,
        'to': toKey,
        'startDate': fromKey,
        'endDate': toKey,
      },
    );
    final seen = <String>{};
    final rows = <LunchEmployeeBalance>[];
    for (final json in _asMapList(
      response.data,
      const ['items', 'employees', 'data', 'results'],
    )) {
      final row = LunchEmployeeBalance.fromJson(json);
      if (row.userId.isNotEmpty && !seen.add(row.userId)) continue;
      rows.add(row);
    }
    return rows;
  }

  Future<void> adjustBalance({
    required String userId,
    required num amount,
    required String reason,
  }) async {
    await _api.post(
      AppConstants.lunchBalanceAdjust,
      data: {'userId': userId, 'amount': amount, 'reason': reason},
    );
  }

  static Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  static Map<String, dynamic> _unwrapPollMap(dynamic raw) {
    final m = _asMap(raw);
    for (final k in const ['poll', 'data', 'item', 'result']) {
      final inner = m[k];
      if (inner is Map) return Map<String, dynamic>.from(inner);
    }
    return m;
  }
}

final lunchRepositoryProvider = Provider<LunchRepository>((ref) {
  return LunchRepository(apiClient: ref.watch(apiClientProvider));
});
