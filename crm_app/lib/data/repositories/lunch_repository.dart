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
    final bundle = await getTodayPolls();
    final out = <LunchPoll>[];
    for (final poll in bundle.items) {
      out.add(await _ensurePollOptions(poll));
    }
    return out;
  }

  Future<LunchPoll> _hydratePoll(LunchPoll poll) async {
    if (poll.id.isEmpty) return poll;
    try {
      final full = await getPoll(poll.id);
      return LunchPoll.merge(poll, full);
    } catch (_) {
      return poll;
    }
  }

  Future<LunchPoll> _ensurePollOptions(LunchPoll poll) async {
    if (poll.id.isEmpty) return poll;
    if (poll.mergedOptions.isNotEmpty && poll.totalVoteCount > 0) return poll;
    return _hydratePoll(poll);
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
    if (hydrated.id.isEmpty || hydrated.totalVoteCount > 0) return hydrated;
    try {
      final summary = await getPollSummary(hydrated.id, poll: hydrated);
      if (summary.totalVotes > 0) {
        hydrated = LunchPoll.merge(summary.poll, hydrated)
            .withReportedTotalVotes(summary.totalVotes);
      } else {
        hydrated = LunchPoll.merge(summary.poll, hydrated);
      }
    } catch (_) {}
    return hydrated;
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

  Future<LunchPoll> getPoll(String pollId) async {
    final response = await _api.get(AppConstants.lunchPollById(pollId));
    return LunchPoll.fromJson(_unwrapPollMap(response.data));
  }

  Future<LunchPoll> createPoll(LunchPoll poll) async {
    final response = await _api.post(
      AppConstants.lunchPolls,
      data: poll.toCreateJson(),
    );
    return LunchPoll.fromJson(_unwrapPollMap(response.data));
  }

  Future<LunchPoll> updatePoll(String pollId, Map<String, dynamic> data) async {
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
    if (summary.totalVotes > 0 && canonical.totalVoteCount == 0) {
      canonical = canonical.withReportedTotalVotes(summary.totalVotes);
    }
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
    final response = await _api.get(
      AppConstants.lunchBalanceEmployees,
      queryParameters: {'from': _dateOnly(from), 'to': _dateOnly(to)},
    );
    return _asMapList(response.data, const ['items', 'employees', 'data'])
        .map(LunchEmployeeBalance.fromJson)
        .toList();
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
