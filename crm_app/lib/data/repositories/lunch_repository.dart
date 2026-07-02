import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
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

  Future<List<LunchPoll>> getTodayPollsHydrated() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final results = await Future.wait<Object>([
      getTodayPolls(),
      listPolls(from: today, to: today),
    ]);
    final bundle = results[0] as LunchTodayBundle;
    final listed = results[1] as List<LunchPoll>;

    final byId = <String, LunchPoll>{};
    for (final poll in [...listed, ...bundle.items]) {
      _upsertTodayPollById(byId, poll);
    }

    final ordered = sortTodayPollsNewestFirst(byId.values.toList());
    final out = <LunchPoll>[];
    for (final poll in ordered) {
      out.add(await _hydratePollForToday(poll));
    }
    return sortTodayPollsNewestFirst(dedupeTodayPolls(out));
  }

  static void _upsertTodayPollById(Map<String, LunchPoll> byId, LunchPoll poll) {
    if (poll.id.isEmpty) return;
    final clean = poll.withoutMyVote();
    final existing = byId[poll.id];
    byId[poll.id] = existing == null
        ? clean
        : LunchPoll.merge(clean, existing).withoutMyVote();
  }

  Future<LunchPoll> _hydratePollForToday(LunchPoll poll) async {
    var hydrated = await _hydratePoll(poll);
    if (hydrated.id.isEmpty) return hydrated;
    final myVote =
        await _myVoteForPoll(hydrated.id, hydrated) ?? hydrated.scopedMyVote;
    if (!hydrated.hasPerOptionVotes) {
      try {
        final summary = await getPollSummary(hydrated.id, poll: hydrated);
        hydrated = LunchPoll.merge(summary.poll.withoutMyVote(), hydrated)
            .withVoteSummary(
          breakdown: summary.menuBreakdown,
          totalVotes: summary.totalVotes,
        );
      } catch (_) {}
    }
    hydrated = LunchPoll(
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
    );
    return hydrated.withPollScopedVotes();
  }

  /// Authoritative per-poll vote — avoids global myVote bleed across same-day polls.
  Future<LunchMyVote?> _myVoteForPoll(String pollId, LunchPoll poll) async {
    try {
      final date = poll.date ?? DateTime.now();
      final day = DateTime(date.year, date.month, date.day);
      final rows = await getVoteHistory(from: day, to: day);
      for (final row in rows) {
        if (row.pollId != pollId) continue;
        final choice = row.menuItem?.trim().toLowerCase() ?? '';
        if (choice.isEmpty) continue;
        for (final opt in poll.mergedOptions) {
          if (opt.label.trim().toLowerCase() == choice) {
            return LunchMyVote(optionId: opt.id, votedAt: row.votedAt);
          }
        }
        for (final opt in poll.mergedOptions) {
          if (lunchOptionKindFrom(row.optionType ?? '') == opt.kind) {
            return LunchMyVote(optionId: opt.id, votedAt: row.votedAt);
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<LunchPoll> _hydratePoll(LunchPoll poll) async {
    if (poll.id.isEmpty) return poll.withPollScopedVotes();
    try {
      final full = await getPoll(poll.id);
      return LunchPoll.merge(poll.withoutMyVote(), full).withPollScopedVotes();
    } catch (_) {
      return poll.withPollScopedVotes();
    }
  }

  Future<List<LunchPoll>> listPollsHydrated({
    DateTime? from,
    DateTime? to,
    String? status,
  }) async {
    final polls = await listPolls(from: from, to: to, status: status);
    final out = <LunchPoll>[];
    for (final poll in polls) {
      out.add(await _hydratePollWithVoteTotal(poll));
    }
    return out;
  }

  Future<LunchPoll> _hydratePollWithVoteTotal(LunchPoll poll) async {
    var hydrated = await _hydratePoll(poll);
    if (hydrated.id.isEmpty) return hydrated;
    if (hydrated.hasPerOptionVotes) return hydrated;
    try {
      final summary = await getPollSummary(hydrated.id, poll: hydrated);
      hydrated = LunchPoll.merge(summary.poll, hydrated).withVoteSummary(
        breakdown: summary.menuBreakdown,
        totalVotes: summary.totalVotes,
      );
    } catch (_) {}
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
    final results = await Future.wait([
      listPolls(from: from, to: to),
      getTodayPolls(),
    ]);
    final listed = results[0] as List<LunchPoll>;
    final today = (results[1] as LunchTodayBundle).items;

    final byId = <String, LunchPoll>{};
    for (final poll in [...today, ...listed]) {
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

  Future<LunchPoll> refreshPollHydrated(String pollId) async {
    return _hydratePollWithVoteTotal(await getPoll(pollId));
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
    final beforeCount = (await getPoll(pollId)).options.length;
    final expectedNew = entries
        .where((e) => (e['id']?.toString() ?? '').isEmpty)
        .length;
    Object? lastError;

    Future<LunchPoll> refresh() => refreshPollHydrated(pollId);

    bool persisted(LunchPoll poll) =>
        expectedNew == 0 || poll.options.length >= beforeCount + expectedNew;

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
    final response = await _api.patch(
      AppConstants.lunchPollStatus(pollId),
      data: {'status': status},
    );
    return LunchPoll.fromJson(_unwrapPollMap(response.data));
  }

  Future<void> deletePoll(String pollId) async {
    await _api.delete(AppConstants.lunchPollById(pollId));
  }

  Future<void> castVote(String pollId, String optionId) async {
    await _api.post(
      AppConstants.lunchPollVote(pollId),
      data: {'optionId': optionId},
    );
  }

  Future<LunchOrderSummary> getPollSummary(String pollId, {LunchPoll? poll}) async {
    final response = await _api.get(AppConstants.lunchPollSummary(pollId));
    LunchPoll? enriched = poll;
    try {
      final full = await getPoll(pollId);
      enriched = LunchPoll.merge(enriched ?? full, full);
    } catch (_) {
      enriched = poll;
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
        ? LunchPoll.merge(summary.poll, enriched)
        : summary.poll;
    canonical = canonical.withVoteSummary(
      breakdown: summary.menuBreakdown,
      totalVotes: summary.totalVotes,
    );
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
