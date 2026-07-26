import '../../core/json_parse.dart';
import '../../core/utils/lunch_poll_schedule.dart';

Map<String, dynamic> _map(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return {};
}

String _str(dynamic v, [String fallback = '']) {
  if (v == null) return fallback;
  return v.toString().trim();
}

String _id(dynamic v) {
  if (v == null) return '';
  if (v is Map) {
    return _str(v[r'$oid'] ?? v['id'] ?? v['_id']);
  }
  return _str(v);
}

DateTime? _parseDateTime(dynamic v) {
  if (v == null) return null;
  if (v is int) {
    return DateTime.fromMillisecondsSinceEpoch(v > 9999999999 ? v : v * 1000);
  }
  final s = _str(v);
  if (s.isEmpty) return null;
  return DateTime.tryParse(s);
}

List<Map<String, dynamic>> _mapList(dynamic raw, [List<String> keys = const []]) {
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

const _pollOptionListKeys = [
  'items',
  'options',
  'pollOptions',
  'choices',
  'results',
  'data',
];

List<LunchPollOption> _parsePollOptions(dynamic raw) {
  return _mapList(raw, _pollOptionListKeys).map(LunchPollOption.fromJson).toList();
}

/// Lunch option type helpers — maps API values to UI labels/colors.
enum LunchOptionKind {
  officeMenu,
  personal,
  offAbsent,
  other,
}

LunchOptionKind lunchOptionKindFrom(String? raw) {
  final s = (raw ?? '').toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
  if (s == 'office' ||
      s == 'office_menu' ||
      s.startsWith('office_') ||
      s == 'menu') {
    return LunchOptionKind.officeMenu;
  }
  if (s == 'personal' || s.contains('personal') || s == 'own') {
    return LunchOptionKind.personal;
  }
  // Exact / prefix tokens only — avoid matching "coffee", "offsite", "office_meal".
  if (s == 'off' ||
      s == 'no' ||
      s == 'absent' ||
      s.startsWith('off_') ||
      s.startsWith('absent')) {
    return LunchOptionKind.offAbsent;
  }
  return LunchOptionKind.other;
}

String lunchOptionKindLabel(LunchOptionKind kind) {
  switch (kind) {
    case LunchOptionKind.officeMenu:
      return 'OFFICE MENU';
    case LunchOptionKind.personal:
      return 'PERSONAL';
    case LunchOptionKind.offAbsent:
      return 'OFF / ABSENT';
    case LunchOptionKind.other:
      return 'OTHER';
  }
}

String lunchOptionKindShortLabel(LunchOptionKind kind) {
  switch (kind) {
    case LunchOptionKind.officeMenu:
      return 'OFFICE';
    case LunchOptionKind.personal:
      return 'PERSONAL';
    case LunchOptionKind.offAbsent:
      return 'OFF';
    case LunchOptionKind.other:
      return 'OTHER';
  }
}

class LunchSettings {
  const LunchSettings({
    this.defaultCostAmount,
    this.allowVoteChange = true,
  });

  final num? defaultCostAmount;
  final bool allowVoteChange;

  factory LunchSettings.fromJson(Map<String, dynamic> json) {
    final m = _unwrap(json);
    return LunchSettings(
      defaultCostAmount: parseOptionalNum(
        m['defaultCostAmount'] ?? m['default_cost_amount'],
      ),
      allowVoteChange:
          parseOptionalBool(m['allowVoteChange'] ?? m['allow_vote_change']) ??
          true,
    );
  }

  Map<String, dynamic> toJson() => {
    'defaultCostAmount': defaultCostAmount,
    'allowVoteChange': allowVoteChange,
  };

  static Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return json;
  }
}

class LunchPollOption {
  const LunchPollOption({
    required this.id,
    required this.label,
    required this.optionType,
    this.voteCount = 0,
    this.voters = const [],
  });

  final String id;
  final String label;
  final String optionType;
  final int voteCount;
  final List<LunchOptionVoter> voters;

  LunchOptionKind get kind => lunchOptionKindFrom(optionType);

  int get effectiveVoteCount {
    if (voteCount > 0) return voteCount;
    return voters.length;
  }

  factory LunchPollOption.fromJson(Map<String, dynamic> json) {
    return LunchPollOption(
      id: _id(json['id'] ?? json['_id'] ?? json['optionId']),
      label: _str(
        json['label'] ??
            json['name'] ??
            json['title'] ??
            json['text'] ??
            json['menuItem'] ??
            json['menu_item'],
      ),
      optionType: _str(
        json['optionType'] ??
            json['option_type'] ??
            json['type'] ??
            json['option_type_id'],
      ),
      voteCount: parseOptionalInt(
        json['votes'] ??
            json['voteCount'] ??
            json['count'] ??
            json['vote_count'] ??
            json['totalVotes'] ??
            json['total_votes'] ??
            json['responseCount'] ??
            json['response_count'] ??
            json['numVotes'] ??
            json['num_votes'],
      ) ?? 0,
      voters: LunchOptionVoter.parseList(
        json['voters'] ?? json['voterNames'] ?? json['users'] ?? json['responses'],
      ),
    );
  }

  Map<String, dynamic> toCreateJson() => {
    'label': label,
    'optionType': optionType,
  };

  /// PUT/append shape — matches production poll options (`orderIndex`, `pollId`).
  Map<String, dynamic> toPutJson({required int orderIndex, String? pollId}) {
    final json = <String, dynamic>{
      'label': label,
      'optionType': optionType,
      'orderIndex': orderIndex,
    };
    if (id.isNotEmpty) json['id'] = id;
    if (pollId != null && pollId.isNotEmpty) json['pollId'] = pollId;
    return json;
  }

  /// Append new options on poll edit — same shape as POST create.
  Map<String, dynamic> toAddOptionJson() => toCreateJson();

  /// PUT payload entry — includes [id] when updating an existing option.
  Map<String, dynamic> toUpdateJson() {
    final json = toCreateJson();
    if (id.isNotEmpty) json['id'] = id;
    return json;
  }

  LunchPollOption copyWith({
    int? voteCount,
    List<LunchOptionVoter>? voters,
  }) {
    return LunchPollOption(
      id: id,
      label: label,
      optionType: optionType,
      voteCount: voteCount ?? this.voteCount,
      voters: voters ?? this.voters,
    );
  }
}

class LunchOptionVoter {
  const LunchOptionVoter({required this.name, this.userId});

  final String name;
  final String? userId;

  factory LunchOptionVoter.fromJson(dynamic json) {
    if (json is String) {
      return LunchOptionVoter(name: json.trim());
    }
    final m = _map(json);
    final user = m['user'] ?? m['employee'];
    var name = _str(m['userName'] ?? m['user_name'] ?? m['name']);
    var uid = _id(m['userId'] ?? m['user_id']);
    if (user is Map) {
      final um = Map<String, dynamic>.from(user);
      if (name.isEmpty) name = _str(um['name']);
      if (uid.isEmpty) uid = _id(um['id'] ?? um['_id']);
    }
    return LunchOptionVoter(
      name: name.isEmpty ? '?' : name,
      userId: uid.isEmpty ? null : uid,
    );
  }

  static List<LunchOptionVoter> parseList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map(LunchOptionVoter.fromJson).toList();
  }
}

class LunchMyVote {
  const LunchMyVote({required this.optionId, this.votedAt});

  final String optionId;
  final DateTime? votedAt;

  factory LunchMyVote.fromJson(Map<String, dynamic> json) {
    return LunchMyVote(
      optionId: _id(json['optionId'] ?? json['option_id'] ?? json['selectedOptionId']),
      votedAt: _parseDateTime(json['votedAt'] ?? json['voted_at']),
    );
  }
}

class LunchPoll {
  const LunchPoll({
    required this.id,
    required this.title,
    this.date,
    this.createdAt,
    this.costAmount,
    this.allowVoteChange = true,
    this.endTime,
    this.status = 'active',
    this.options = const [],
    this.myVote,
    this.results = const [],
    this.reportedTotalVotes,
  });

  final String id;
  final String title;
  final DateTime? date;
  final DateTime? createdAt;
  final num? costAmount;
  final bool allowVoteChange;
  final String? endTime;
  final String status;
  final List<LunchPollOption> options;
  final LunchMyVote? myVote;
  final List<LunchPollOption> results;
  final int? reportedTotalVotes;

  bool get isActive => status.toLowerCase() == 'active';
  bool get isClosed => status.toLowerCase() == 'closed';
  bool get isCancelled => status.toLowerCase() == 'cancelled';

  bool get isPriorDayPoll {
    final d = date;
    if (d == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final pollDay = DateTime(d.year, d.month, d.day);
    return pollDay.isBefore(today);
  }

  /// Active poll from a previous day that was reopened for voting today.
  bool get isReactivatedPoll =>
      isPriorDayPoll &&
      isActive &&
      !isCancelled &&
      !lunchPollIsPastEndTime(
        endTime: endTime,
        pollDate: date,
        status: status,
      );

  /// Do not invent `active` for intentionally closed polls.
  /// Visibility of closed same-day polls is handled by [appearsOnMyLunchCard].
  LunchPoll resolvedForMyLunch() => this;

  bool get showOnMyLunch => lunchPollShowOnMyLunch(
        id: id,
        status: status,
        date: date,
        endTime: endTime,
        isCancelled: isCancelled,
      );

  /// Open/reactivated polls plus same-day closed polls (greyed out).
  bool get appearsOnMyLunchCard {
    if (showOnMyLunch) return true;
    final d = date;
    if (d == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final pollDay = DateTime(d.year, d.month, d.day);
    return !pollDay.isBefore(today);
  }

  static bool _dateIsBeforeToday(DateTime? d) {
    if (d == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    return day.isBefore(today);
  }

  static bool _allowVoteChangeForPollDate({
    required DateTime? pollDate,
    required bool value,
  }) {
    if (_dateIsBeforeToday(pollDate)) return false;
    return value;
  }

  /// Best-effort timestamp for newest-first ordering.
  DateTime get recencyInstant =>
      createdAt?.toLocal() ??
      _createdAtFromObjectId(id) ??
      date?.toLocal() ??
      DateTime.fromMillisecondsSinceEpoch(0);

  /// Options merged with live result counts + voter avatars.
  List<LunchPollOption> get mergedOptions {
    if (options.isEmpty) return results;
    if (results.isEmpty) return options;

    final byId = {for (final r in results) if (r.id.isNotEmpty) r.id: r};
    final byLabel = {for (final r in results) if (r.label.isNotEmpty) r.label: r};

    return options.map((o) {
      // Prefer id match — label fallback only when the option has no id (legacy API).
      final r = o.id.isNotEmpty
          ? byId[o.id]
          : (o.label.isNotEmpty ? byLabel[o.label] : null);
      if (r == null) return o;
      return o.copyWith(
        voteCount: _resolvedVoteCount(o, r),
        voters: r.voters.isNotEmpty ? r.voters : o.voters,
      );
    }).toList();
  }

  Set<String> get _optionIds => {
    for (final o in mergedOptions) if (o.id.isNotEmpty) o.id,
  };

  /// [myVote] only when its option id belongs to this poll's choices.
  LunchMyVote? get scopedMyVote {
    final vote = myVote;
    if (vote == null || vote.optionId.isEmpty) return null;
    final ids = _optionIds;
    // Without option ids we cannot safely highlight a choice.
    if (ids.isEmpty || !ids.contains(vote.optionId)) return null;
    return vote;
  }

  List<LunchPollOption> get _scopedResults {
    if (options.isEmpty || results.isEmpty) return results;
    final ids = _optionIds;
    if (ids.isEmpty) return results;
    return results.where((r) => r.id.isEmpty || ids.contains(r.id)).toList();
  }

  /// Drops cross-poll vote bleed from shared option ids / API shells.
  LunchPoll withPollScopedVotes() {
    final vote = scopedMyVote;
    final filtered = _scopedResults;
    if (vote == myVote && filtered.length == results.length) return this;
    return LunchPoll(
      id: id,
      title: title,
      date: date,
      createdAt: createdAt,
      costAmount: costAmount,
      allowVoteChange: allowVoteChange,
      endTime: endTime,
      status: status,
      options: options,
      myVote: vote,
      results: filtered,
      reportedTotalVotes: reportedTotalVotes,
    );
  }

  LunchPoll withoutMyVote() {
    if (myVote == null) return this;
    return LunchPoll(
      id: id,
      title: title,
      date: date,
      createdAt: createdAt,
      costAmount: costAmount,
      allowVoteChange: allowVoteChange,
      endTime: endTime,
      status: status,
      options: options,
      results: results,
      reportedTotalVotes: reportedTotalVotes,
    );
  }

  /// Undo an optimistic [withMyVote] back to [priorVote] (or no vote).
  ///
  /// When [adjustCounts] is false, only [myVote] is restored — use after a
  /// concurrent refresh replaced option counts with server values.
  LunchPoll restoreMyVote(LunchMyVote? priorVote, {bool adjustCounts = true}) {
    final priorId = priorVote?.optionId ?? '';
    final currentId = myVote?.optionId ?? '';
    if (!adjustCounts) {
      return LunchPoll(
        id: id,
        title: title,
        date: date,
        createdAt: createdAt,
        costAmount: costAmount,
        allowVoteChange: allowVoteChange,
        endTime: endTime,
        status: status,
        options: options,
        myVote: priorVote,
        results: results,
        reportedTotalVotes: reportedTotalVotes,
      );
    }
    if (priorId == currentId) {
      if (priorVote == null) return withoutMyVote();
      // Same option — still restore prior votedAt after a no-op re-tap.
      if (myVote?.votedAt == priorVote.votedAt) return this;
      return LunchPoll(
        id: id,
        title: title,
        date: date,
        createdAt: createdAt,
        costAmount: costAmount,
        allowVoteChange: allowVoteChange,
        endTime: endTime,
        status: status,
        options: options,
        myVote: priorVote,
        results: results,
        reportedTotalVotes: reportedTotalVotes,
      );
    }
    if (priorId.isNotEmpty) {
      return withMyVote(priorId, votedAt: priorVote?.votedAt);
    }

    // Clear first/optimistic vote and decrement counts.
    LunchPollOption adjust(LunchPollOption o) {
      var count = o.effectiveVoteCount;
      if (o.id == currentId && count > 0) count--;
      return o.copyWith(
        voteCount: count,
        voters: count == 0 ? const [] : o.voters,
      );
    }

    final adjustedOptions = options.map(adjust).toList();
    final adjustedResults = results.map(adjust).toList();
    final nextReported = (reportedTotalVotes != null && reportedTotalVotes! > 0)
        ? reportedTotalVotes! - 1
        : reportedTotalVotes;

    return LunchPoll(
      id: id,
      title: title,
      date: date,
      createdAt: createdAt,
      costAmount: costAmount,
      allowVoteChange: allowVoteChange,
      endTime: endTime,
      status: status,
      options: adjustedOptions,
      results: adjustedResults,
      reportedTotalVotes: nextReported != null && nextReported <= 0 ? null : nextReported,
    );
  }

  /// Whether option vote counts match [other] (used to detect concurrent refresh).
  bool hasSameOptionCounts(LunchPoll other) {
    final mine = {
      for (final o in mergedOptions)
        if (o.id.isNotEmpty) o.id: o.effectiveVoteCount,
    };
    final theirs = {
      for (final o in other.mergedOptions)
        if (o.id.isNotEmpty) o.id: o.effectiveVoteCount,
    };
    if (mine.length != theirs.length) return false;
    for (final e in mine.entries) {
      if (theirs[e.key] != e.value) return false;
    }
    return true;
  }

  /// Resolve a history row to a poll option. Prefer option id / exact label.
  /// Never guess among multiple office-menu items by type alone.
  static LunchMyVote? myVoteFromHistoryRow(
    LunchVoteHistoryRow row,
    List<LunchPollOption> options, {
    DateTime? votedAt,
  }) {
    if (options.isEmpty) return null;
    final at = votedAt ?? row.votedAt;

    final optionId = row.optionId?.trim() ?? '';
    if (optionId.isNotEmpty) {
      for (final opt in options) {
        if (opt.id == optionId) {
          return LunchMyVote(optionId: opt.id, votedAt: at);
        }
      }
    }

    String normalize(String raw) => raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');

    final choice = normalize(row.menuItem ?? '');
    if (choice.isNotEmpty) {
      for (final opt in options) {
        if (normalize(opt.label) == choice) {
          return LunchMyVote(optionId: opt.id, votedAt: at);
        }
      }
      // No partial/contains matching — too easy to pick the wrong office menu.
    }

    final kind = lunchOptionKindFrom(row.optionType ?? '');
    if (kind == LunchOptionKind.other) return null;
    final sameKind = options.where((o) => o.kind == kind).toList();
    // Only safe when this poll has exactly one option of that kind
    // (e.g. Personal / Off). Multiple office menus must not guess.
    if (sameKind.length == 1 && sameKind.first.id.isNotEmpty) {
      return LunchMyVote(optionId: sameKind.first.id, votedAt: at);
    }
    return null;
  }

  static LunchMyVote? _resolveMyVoteAfterSnapshot({
    required List<LunchPollOption> options,
    LunchMyVote? prior,
    LunchMyVote? incoming,
  }) {
    if (prior == null) {
      return _resolveScopedMyVote(
        options: options,
        preferred: incoming,
        fallback: null,
      );
    }
    if (incoming == null) {
      return _resolveScopedMyVote(
        options: options,
        preferred: prior,
        fallback: null,
      );
    }
    if (prior.optionId == incoming.optionId) {
      return _resolveScopedMyVote(
        options: options,
        preferred: incoming,
        fallback: prior,
      );
    }

    final priorAt = prior.votedAt;
    final incomingAt = incoming.votedAt;
    if (priorAt != null &&
        (incomingAt == null || priorAt.isAfter(incomingAt))) {
      return _resolveScopedMyVote(
        options: options,
        preferred: prior,
        fallback: incoming,
      );
    }
    return _resolveScopedMyVote(
      options: options,
      preferred: incoming,
      fallback: prior,
    );
  }

  static LunchMyVote? _resolveScopedMyVote({
    required List<LunchPollOption> options,
    LunchMyVote? preferred,
    LunchMyVote? fallback,
  }) {
    final ids = {for (final o in options) if (o.id.isNotEmpty) o.id};
    if (ids.isEmpty) return null;
    if (preferred != null &&
        preferred.optionId.isNotEmpty &&
        ids.contains(preferred.optionId)) {
      return preferred;
    }
    if (fallback != null &&
        fallback.optionId.isNotEmpty &&
        ids.contains(fallback.optionId)) {
      return fallback;
    }
    return null;
  }

  static int _resolvedVoteCount(LunchPollOption primary, LunchPollOption? result) {
    if (result != null && result.voteCount > 0) return result.voteCount;
    if (primary.voteCount > 0) return primary.voteCount;
    if (result != null && result.voters.isNotEmpty) return result.voters.length;
    return primary.voters.length;
  }

  /// Options with best-effort vote totals for admin edit / summary views.
  List<LunchPollOption> optionsWithVoteTotals([
    List<LunchMenuBreakdownRow>? breakdown,
  ]) {
    final merged = mergedOptions
        .map((o) => o.copyWith(voteCount: _resolvedVoteCount(o, null)))
        .toList();
    if (breakdown == null || breakdown.isEmpty) return merged;

    final byLabel = <String, LunchMenuBreakdownRow>{};
    for (final row in breakdown) {
      final key = row.label.trim().toLowerCase();
      if (key.isNotEmpty) byLabel[key] = row;
    }

    return merged.map((o) {
      final row = o.label.isNotEmpty ? byLabel[o.label.trim().toLowerCase()] : null;
      if (row == null) return o;
      var count = o.voteCount;
      if (count <= 0 && row.votes > 0) count = row.votes;
      if (count <= 0 && row.voters.isNotEmpty) count = row.voters.length;
      return o.copyWith(
        voteCount: count,
        voters: row.voters.isNotEmpty ? row.voters : o.voters,
      );
    }).toList();
  }

  int get totalVoteCount {
    if (reportedTotalVotes != null && reportedTotalVotes! > 0) {
      return reportedTotalVotes!;
    }
    // Same rule as option bars ([effectiveVoteCount]) so fractions stay ≤ 1.
    return mergedOptions.fold<int>(0, (sum, o) => sum + o.effectiveVoteCount);
  }

  String get statusHint {
    switch (status.toLowerCase()) {
      case 'cancelled':
        return 'Poll cancelled';
      case 'closed':
        return 'Poll closed';
      case 'active':
        return endTime != null && endTime!.isNotEmpty
            ? 'Closes at $endTime'
            : 'Poll open';
      default:
        return status;
    }
  }

  /// Prefer [primary] ids/status; fill missing options/results/votes from [secondary].
  static LunchPoll merge(LunchPoll primary, LunchPoll? secondary) {
    if (secondary == null) return primary.withPollScopedVotes();
    final options =
        primary.options.isNotEmpty ? primary.options : secondary.options;
    final pollDate = primary.date ?? secondary.date;
    final endTime = preferPollEndTime(
      prior: primary.endTime,
      incoming: secondary.endTime,
      pollDate: pollDate,
    );
    final merged = LunchPoll(
      id: primary.id.isNotEmpty ? primary.id : secondary.id,
      title: primary.title.isNotEmpty ? primary.title : secondary.title,
      date: pollDate,
      createdAt: _newerDateTime(primary.createdAt, secondary.createdAt),
      costAmount: primary.costAmount ?? secondary.costAmount,
      allowVoteChange: _allowVoteChangeForPollDate(
        pollDate: pollDate,
        // False wins so list stubs (default true) cannot override an explicit lock.
        value: primary.allowVoteChange && secondary.allowVoteChange,
      ),
      endTime: endTime,
      status: _resolveMergedStatus(
        priorStatus: primary.status,
        incomingStatus: secondary.status,
        priorEndTime: primary.endTime,
        incomingEndTime: secondary.endTime,
        resolvedEndTime: endTime,
        pollDate: pollDate,
      ),
      options: options,
      results: _pickRicherResults(primary.results, secondary.results),
      myVote: _resolveScopedMyVote(
        options: options.isNotEmpty ? options : _pickRicherResults(primary.results, secondary.results),
        preferred: secondary.myVote,
        fallback: primary.myVote,
      ),
      reportedTotalVotes:
          primary.reportedTotalVotes ?? secondary.reportedTotalVotes,
    );
    return merged.withPollScopedVotes();
  }

  /// After casting/changing a vote: keep server counts, but prefer [local] myVote when
  /// the server response is missing or still shows the previous choice.
  static LunchPoll mergeAfterVote({
    required LunchPoll local,
    required LunchPoll server,
  }) {
    final merged = merge(server, local);
    final localId = local.myVote?.optionId ?? '';
    final serverId = server.myVote?.optionId ?? '';
    final LunchMyVote? preferred;
    if (localId.isNotEmpty && (serverId.isEmpty || serverId != localId)) {
      preferred = local.myVote;
    } else {
      preferred = server.myVote ?? local.myVote;
    }
    // Server terminal status must win — merge() can keep a viable local `active`.
    final serverStatus = server.status.toLowerCase();
    final status = (serverStatus == 'closed' || serverStatus == 'cancelled')
        ? serverStatus
        : merged.status;
    // Non-empty server endTime is authoritative (same rule as applyServerSnapshot).
    final serverEnd = server.endTime?.trim();
    final endTime = (serverEnd != null && serverEnd.isNotEmpty)
        ? serverEnd
        : merged.endTime;
    return LunchPoll(
      id: merged.id,
      title: merged.title,
      date: merged.date,
      createdAt: merged.createdAt,
      costAmount: merged.costAmount,
      allowVoteChange: merged.allowVoteChange,
      endTime: endTime,
      status: status,
      options: merged.options,
      results: merged.results,
      myVote: _resolveScopedMyVote(
        options: merged.mergedOptions,
        preferred: preferred,
        fallback: null,
      ),
      reportedTotalVotes: merged.reportedTotalVotes,
    ).withPollScopedVotes();
  }

  static String _pickStatus(String a, String b) {
    const terminal = {'closed', 'cancelled'};
    final al = a.toLowerCase();
    final bl = b.toLowerCase();
    if (terminal.contains(bl)) return bl;
    if (terminal.contains(al)) return al;
    return al.isNotEmpty ? al : bl;
  }

  static bool _isViableActiveStatus({
    required String status,
    required String? endTime,
    required DateTime? pollDate,
  }) {
    if (status.toLowerCase() != 'active') return false;
    if (endTime == null || endTime.trim().isEmpty) return true;
    return !lunchPollIsPastEndTime(
      endTime: endTime,
      pollDate: pollDate,
      status: 'active',
    );
  }

  /// Keep reactivated polls open when the API still returns a stale closed snapshot.
  static String _resolveMergedStatus({
    required String priorStatus,
    required String incomingStatus,
    required String? priorEndTime,
    required String? incomingEndTime,
    required String? resolvedEndTime,
    required DateTime? pollDate,
  }) {
    // Authoritative closed/cancelled from the server always wins.
    const terminal = {'closed', 'cancelled'};
    final incoming = incomingStatus.toLowerCase();
    if (terminal.contains(incoming)) return incoming;

    final priorActive = _isViableActiveStatus(
      status: priorStatus,
      endTime: priorEndTime ?? resolvedEndTime,
      pollDate: pollDate,
    );
    final incomingActive = _isViableActiveStatus(
      status: incomingStatus,
      endTime: incomingEndTime ?? resolvedEndTime,
      pollDate: pollDate,
    );

    if (priorActive || incomingActive) {
      if (priorStatus.toLowerCase() == 'active' ||
          incomingStatus.toLowerCase() == 'active') {
        return 'active';
      }
    }

    return _pickStatus(priorStatus, incomingStatus);
  }

  LunchPoll applyServerSnapshot(LunchPoll fresh) {
    final pollDate = _preferredPollDate(fresh.date, date);
    // Non-empty server endTime is authoritative. Local reopen/shorten flows pin
    // the intended end onto [fresh] before merge when the list API lags.
    final incomingEnd = fresh.endTime?.trim();
    final resolvedEnd = (incomingEnd != null && incomingEnd.isNotEmpty)
        ? incomingEnd
        : endTime;

    final priorMerged = mergedOptions;
    final List<LunchPollOption> baseOptions;
    if (fresh.options.isNotEmpty) {
      baseOptions = fresh.options;
    } else if (options.isNotEmpty) {
      baseOptions = options;
    } else if (fresh.results.isNotEmpty) {
      baseOptions = fresh.results;
    } else {
      baseOptions = results;
    }
    // GET /polls/:id often returns options with zero tallies — keep prior votes.
    final resolvedOptions =
        _mergeOptionsPreservingVotes(baseOptions, priorMerged);

    final freshHasOptionVotes =
        resolvedOptions.any((o) => o.effectiveVoteCount > 0);
    final List<LunchPollOption> nextResults;
    if (fresh.results.isNotEmpty) {
      nextResults = _pickRicherResults(
        fresh.results,
        results,
      );
    } else if (fresh.options.isNotEmpty && freshHasOptionVotes) {
      // Vote tallies already live on options — drop stale result rows.
      nextResults = const <LunchPollOption>[];
    } else if (fresh.options.isNotEmpty) {
      // Sparse options shell — never wipe richer prior results (View all votes).
      nextResults = results;
    } else {
      nextResults = results;
    }

    return LunchPoll(
      id: fresh.id.isNotEmpty ? fresh.id : id,
      title: fresh.title.isNotEmpty ? fresh.title : title,
      date: pollDate,
      createdAt: fresh.createdAt ?? createdAt,
      costAmount: fresh.costAmount ?? costAmount,
      allowVoteChange: _allowVoteChangeForPollDate(
        pollDate: pollDate,
        // Sparse shells default allowVoteChange=true — never unlock a local lock.
        value: allowVoteChange && fresh.allowVoteChange,
      ),
      endTime: resolvedEnd,
      status: _resolveMergedStatus(
        priorStatus: status,
        incomingStatus: fresh.status.isNotEmpty ? fresh.status : status,
        priorEndTime: endTime,
        incomingEndTime: fresh.endTime,
        resolvedEndTime: resolvedEnd,
        pollDate: pollDate,
      ),
      options: resolvedOptions,
      results: nextResults,
      myVote: _resolveMyVoteAfterSnapshot(
        options: resolvedOptions,
        prior: myVote,
        incoming: fresh.myVote,
      ),
      reportedTotalVotes: _pickHigherVoteTotal(
        reportedTotalVotes,
        fresh.reportedTotalVotes,
      ),
    ).withPollScopedVotes();
  }

  /// Copy vote counts / voter lists from [prior] onto matching [fresh] options
  /// when the fresh shell has empty tallies (common on GET poll).
  static List<LunchPollOption> _mergeOptionsPreservingVotes(
    List<LunchPollOption> fresh,
    List<LunchPollOption> prior,
  ) {
    if (fresh.isEmpty) return prior;
    if (prior.isEmpty) return fresh;
    final byId = {
      for (final o in prior)
        if (o.id.isNotEmpty) o.id: o,
    };
    final byLabel = {
      for (final o in prior)
        if (o.label.trim().isNotEmpty) o.label.trim().toLowerCase(): o,
    };
    return fresh.map((o) {
      final p = o.id.isNotEmpty
          ? byId[o.id]
          : byLabel[o.label.trim().toLowerCase()];
      if (p == null) return o;
      final count = o.effectiveVoteCount > 0
          ? o.effectiveVoteCount
          : p.effectiveVoteCount;
      final voters = o.voters.isNotEmpty ? o.voters : p.voters;
      if (count == o.voteCount && identical(voters, o.voters)) return o;
      return o.copyWith(voteCount: count, voters: voters);
    }).toList();
  }

  /// Prefer authoritative [fresh] totals when present (including lower values).
  static int? _pickHigherVoteTotal(int? prior, int? fresh) {
    if (fresh != null && fresh > 0) return fresh;
    if (prior != null && prior > 0) return prior;
    return fresh ?? prior;
  }

  static DateTime? _preferredPollDate(DateTime? fresh, DateTime? prior) {
    // Server/fresh date wins when present (admin may correct a date backward).
    if (fresh != null) return fresh;
    return prior;
  }

  LunchPoll withReportedTotalVotes(int total) {
    return LunchPoll(
      id: id,
      title: title,
      date: date,
      createdAt: createdAt,
      costAmount: costAmount,
      allowVoteChange: allowVoteChange,
      endTime: endTime,
      status: status,
      options: options,
      myVote: myVote,
      results: results,
      reportedTotalVotes: total,
    );
  }

  bool get hasPerOptionVotes =>
      mergedOptions.any((o) => o.effectiveVoteCount > 0);

  LunchPoll withVoteSummary({
    List<LunchMenuBreakdownRow> breakdown = const [],
    int totalVotes = 0,
  }) {
    final opts = optionsWithVoteTotals(breakdown);
    final hasRich = opts.any((o) => o.effectiveVoteCount > 0);
    return LunchPoll(
      id: id,
      title: title,
      date: date,
      createdAt: createdAt,
      costAmount: costAmount,
      allowVoteChange: allowVoteChange,
      endTime: endTime,
      status: status,
      // Keep tallies on options so View-all-votes / bars stay correct even when
      // a later snapshot clears results.
      options: hasRich ? opts : options,
      myVote: myVote,
      results: hasRich ? opts : results,
      reportedTotalVotes: totalVotes > 0 ? totalVotes : reportedTotalVotes,
    );
  }

  /// Attach employee summary rows onto option voter lists + counts.
  LunchPoll attachEmployeeVotes(List<LunchEmployeeVoteRow> employees) {
    if (employees.isEmpty) return this;
    final byLabel = <String, List<LunchOptionVoter>>{};
    for (final row in employees) {
      final key = row.choice.trim().toLowerCase();
      if (key.isEmpty) continue;
      byLabel
          .putIfAbsent(key, () => <LunchOptionVoter>[])
          .add(
            LunchOptionVoter(
              name: row.userName,
              userId: row.userId.isEmpty ? null : row.userId,
            ),
          );
    }
    if (byLabel.isEmpty) return this;

    List<LunchPollOption> paint(List<LunchPollOption> source) {
      return source.map((o) {
        final voters = byLabel[o.label.trim().toLowerCase()];
        if (voters == null || voters.isEmpty) return o;
        final count = o.effectiveVoteCount > voters.length
            ? o.effectiveVoteCount
            : voters.length;
        return o.copyWith(voteCount: count, voters: voters);
      }).toList();
    }

    final nextOptions = options.isNotEmpty ? paint(options) : options;
    final nextResults = results.isNotEmpty
        ? paint(results)
        : (nextOptions.isNotEmpty ? nextOptions : results);
    return LunchPoll(
      id: id,
      title: title,
      date: date,
      createdAt: createdAt,
      costAmount: costAmount,
      allowVoteChange: allowVoteChange,
      endTime: endTime,
      status: status,
      options: nextOptions,
      myVote: myVote,
      results: nextResults,
      reportedTotalVotes: reportedTotalVotes,
    ).withPollScopedVotes();
  }

  LunchPoll withMyVote(
    String optionId, {
    bool? allowVoteChangeOverride,
    DateTime? votedAt,
  }) {
    final previousId = myVote?.optionId ?? '';
    LunchPollOption adjustCounts(LunchPollOption o) {
      var count = o.effectiveVoteCount;
      if (previousId.isNotEmpty &&
          previousId != optionId &&
          o.id == previousId &&
          count > 0) {
        count--;
      }
      if (o.id == optionId && previousId != optionId) {
        count++;
      }
      return o.copyWith(
        voteCount: count,
        // Avoid effectiveVoteCount falling back to stale voters when count is 0.
        voters: count == 0 ? const [] : o.voters,
      );
    }

    final adjustedResults = results.map(adjustCounts).toList();
    final adjustedOptions = options.map(adjustCounts).toList();
    final allowChanges = allowVoteChangeOverride ?? allowVoteChange;
    final isFirstVote = previousId.isEmpty && optionId.isNotEmpty;
    final optionSum = adjustedOptions.fold<int>(0, (s, o) => s + o.voteCount);
    final resultSum = adjustedResults.fold<int>(0, (s, o) => s + o.voteCount);
    final counted = optionSum > 0 ? optionSum : resultSum;
    final int? nextReported;
    if (isFirstVote) {
      // Prefer option/result sums when reported was missing/stale so bars stay coherent.
      final base = (reportedTotalVotes != null && reportedTotalVotes! > 0)
          ? reportedTotalVotes!
          : (counted > 1 ? counted - 1 : 0);
      nextReported = base + 1;
    } else {
      nextReported = reportedTotalVotes;
    }

    return LunchPoll(
      id: id,
      title: title,
      date: date,
      createdAt: createdAt,
      costAmount: costAmount,
      allowVoteChange: allowChanges,
      endTime: endTime,
      status: status,
      options: adjustedOptions,
      myVote: LunchMyVote(
        optionId: optionId,
        votedAt: votedAt ?? DateTime.now(),
      ),
      results: adjustedResults,
      reportedTotalVotes: nextReported,
    );
  }

  static List<LunchPollOption> _pickRicherResults(
    List<LunchPollOption> a,
    List<LunchPollOption> b,
  ) {
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;
    final aVotes = a.fold<int>(0, (s, o) => s + o.voteCount);
    final bVotes = b.fold<int>(0, (s, o) => s + o.voteCount);
    final aVoters = a.fold<int>(0, (s, o) => s + o.voters.length);
    final bVoters = b.fold<int>(0, (s, o) => s + o.voters.length);
    if (bVotes > aVotes || bVoters > aVoters) return b;
    return a;
  }

  factory LunchPoll.fromJson(Map<String, dynamic> json) {
    final m = _map(json);
    final optsRaw = m['options'] ?? m['pollOptions'] ?? m['choices'];
    final resultsRaw = m['results'] ?? m['resultCounts'] ?? m['voteCounts'];
    LunchMyVote? vote;
    final mv = m['myVote'] ?? m['my_vote'] ?? m['userVote'];
    if (mv is Map) {
      vote = LunchMyVote.fromJson(Map<String, dynamic>.from(mv));
    }

    return LunchPoll(
      id: _id(m['id'] ?? m['_id'] ?? m['pollId']),
      title: _str(m['title'] ?? m['name'], 'Lunch'),
      date: DateTime.tryParse(_str(m['date'] ?? m['pollDate'])),
      createdAt: _parseDateTime(
        m['createdAt'] ?? m['created_at'] ?? m['updatedAt'] ?? m['updated_at'],
      ),
      costAmount: parseOptionalNum(m['costAmount'] ?? m['cost_amount']),
      allowVoteChange:
          parseOptionalBool(m['allowVoteChange'] ?? m['allow_vote_change']) ??
          true,
      endTime: _str(m['endTime'] ?? m['end_time']).isEmpty
          ? null
          : _str(m['endTime'] ?? m['end_time']),
      status: _str(m['status'], 'active').toLowerCase(),
      options: _parsePollOptions(optsRaw),
      myVote: vote,
      results: _parsePollOptions(resultsRaw),
      reportedTotalVotes: parseOptionalInt(
        m['totalVotes'] ?? m['total_votes'] ?? m['voteCount'] ?? m['vote_count'],
      ),
    );
  }

  Map<String, dynamic> toCreateJson() => {
    if (date != null) 'date': _dateOnly(date!),
    'title': title,
    if (costAmount != null) ...{
      'costAmount': costAmount,
      'cost_amount': costAmount,
    },
    'allowVoteChange': allowVoteChange,
    'allow_vote_change': allowVoteChange,
    if (endTime != null && endTime!.isNotEmpty) ...{
      'endTime': endTime,
      'end_time': endTime,
    },
    'options': optionsOrderedForCreate().map((o) => o.toCreateJson()).toList(),
  };

  /// Web/API order: office menu items, then Personal, then Off.
  List<LunchPollOption> optionsOrderedForCreate() {
    final menus = <LunchPollOption>[];
    final personal = <LunchPollOption>[];
    final off = <LunchPollOption>[];
    final other = <LunchPollOption>[];
    for (final o in options) {
      switch (o.kind) {
        case LunchOptionKind.officeMenu:
          menus.add(o);
        case LunchOptionKind.personal:
          personal.add(o);
        case LunchOptionKind.offAbsent:
          off.add(o);
        case LunchOptionKind.other:
          other.add(o);
      }
    }
    return [...menus, ...personal, ...off, ...other];
  }

  /// Staged create fallback — Personal + Off first, office menus appended.
  ({List<LunchPollOption> initial, List<LunchPollOption> extras})
      partitionForCreate() {
    if (options.length <= 2) {
      return (initial: options, extras: const []);
    }
    final ordered = optionsOrderedForCreate();
    final menus = ordered.where((o) => o.kind == LunchOptionKind.officeMenu).toList();
    final personal = ordered.where((o) => o.kind == LunchOptionKind.personal).toList();
    final off = ordered.where((o) => o.kind == LunchOptionKind.offAbsent).toList();
    final initial = <LunchPollOption>[
      if (personal.isNotEmpty) personal.first,
      if (off.isNotEmpty) off.first,
    ];
    final extras = <LunchPollOption>[
      ...menus,
      if (personal.length > 1) ...personal.skip(1),
      if (off.length > 1) ...off.skip(1),
      ...ordered.where((o) => o.kind == LunchOptionKind.other),
    ];
    return (initial: initial, extras: extras);
  }

  LunchPoll withOptions(List<LunchPollOption> next) {
    return LunchPoll(
      id: id,
      title: title,
      date: date,
      createdAt: createdAt,
      costAmount: costAmount,
      allowVoteChange: allowVoteChange,
      endTime: endTime,
      status: status,
      options: next,
      myVote: myVote,
      results: results,
      reportedTotalVotes: reportedTotalVotes,
    );
  }

  /// PUT payloads for poll edit — never send `options` and `optionUpdates` together.
  List<Map<String, dynamic>> toUpdateJsonSequence({LunchPoll? original}) {
    final payloads = <Map<String, dynamic>>[];
    final parts = partitionUpdateOptions(original);
    final optionsRemoved = _optionsRemoved(original);

    if (_metadataChanged(original)) {
      payloads.add(toUpdateBaseJson());
    }
    // Full options PUT when adding OR removing — otherwise deletes never persist.
    if (parts.newOptions.isNotEmpty || optionsRemoved) {
      payloads.add({'options': optionsForPut()});
    } else if (parts.optionUpdates.isNotEmpty) {
      payloads.add({'optionUpdates': parts.optionUpdates});
    }

    if (payloads.isEmpty) {
      payloads.add(toUpdateBaseJson());
    }
    return payloads;
  }

  /// Full options array for PUT — production shape with orderIndex + pollId.
  List<Map<String, dynamic>> optionsForPut() {
    final ordered = optionsOrderedForCreate();
    final pollId = id;
    return [
      for (var i = 0; i < ordered.length; i++)
        ordered[i].toPutJson(
          orderIndex: i,
          pollId: pollId.isEmpty ? null : pollId,
        ),
    ];
  }

  /// Splits new vs changed options for separate PUT requests.
  ({List<Map<String, dynamic>> newOptions, List<Map<String, dynamic>> optionUpdates})
      partitionUpdateOptions(LunchPoll? original) {
    final newOptions = <Map<String, dynamic>>[];
    final optionUpdates = <Map<String, dynamic>>[];
    final byId = original != null
        ? {for (final o in original.options) o.id: o}
        : <String, LunchPollOption>{};
    final ordered = optionsOrderedForCreate();
    final indexById = {
      for (var i = 0; i < ordered.length; i++)
        if (ordered[i].id.isNotEmpty) ordered[i].id: i,
    };
    final pollId = id.isEmpty ? null : id;

    for (final o in options) {
      if (o.id.isEmpty) {
        newOptions.add(o.toAddOptionJson());
      } else {
        final prev = byId[o.id];
        if (prev != null &&
            (prev.label.trim() != o.label.trim() ||
                prev.optionType != o.optionType)) {
          optionUpdates.add(
            o.toPutJson(orderIndex: indexById[o.id] ?? 0, pollId: pollId),
          );
        }
      }
    }
    return (newOptions: newOptions, optionUpdates: optionUpdates);
  }

  bool _optionsRemoved(LunchPoll? original) {
    if (original == null) return false;
    final currentIds = {
      for (final o in options)
        if (o.id.isNotEmpty) o.id,
    };
    return original.options.any(
      (o) => o.id.isNotEmpty && !currentIds.contains(o.id),
    );
  }

  bool _metadataChanged(LunchPoll? original) {
    if (original == null) return true;
    if (title.trim() != original.title.trim()) return true;
    if (allowVoteChange != original.allowVoteChange) return true;
    if (costAmount != original.costAmount) return true;
    final d = date;
    final od = original.date;
    if (d != null && od != null && _dateOnly(d) != _dateOnly(od)) return true;
    if ((endTime ?? '') != (original.endTime ?? '')) return true;
    return false;
  }

  /// Base metadata fields only — no option arrays (API rejects both keys together).
  Map<String, dynamic> toUpdateBaseJson() => {
    if (date != null) 'date': _dateOnly(date!),
    'title': title,
    if (costAmount != null) 'costAmount': costAmount,
    'allowVoteChange': allowVoteChange,
    if (endTime != null && endTime!.isNotEmpty) 'endTime': endTime,
  };

  static String _dateOnly(DateTime d) {
    final l = d.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
  }
}

LunchPoll _applyTodayFeaturedShell({
  required LunchPoll poll,
  required List<LunchPollOption> topOptions,
  required List<LunchPollOption> topResults,
  LunchMyVote? topVote,
}) {
  var merged = poll;
  LunchPoll shell({
    List<LunchPollOption> options = const [],
    List<LunchPollOption> results = const [],
    LunchMyVote? vote,
  }) =>
      LunchPoll(
        id: merged.id,
        title: merged.title,
        // Keep poll identity fields — default status 'active' would revive closed.
        date: merged.date,
        status: merged.status,
        endTime: merged.endTime,
        options: options,
        results: results,
        myVote: vote,
      );
  if (topVote != null ||
      topResults.isNotEmpty ||
      topOptions.isNotEmpty) {
    merged = LunchPoll.merge(
      merged,
      shell(options: topOptions, results: topResults, vote: topVote),
    );
  }
  if (merged.mergedOptions.isEmpty && topOptions.isNotEmpty) {
    merged = LunchPoll.merge(
      merged,
      shell(options: topOptions, results: topResults),
    );
  }
  return merged.withPollScopedVotes();
}

/// Keeps first-seen order; merges only duplicate poll ids.
List<LunchPoll> dedupeTodayPolls(List<LunchPoll> polls) {
  final seenIds = <String>{};
  final result = <LunchPoll>[];
  for (final poll in polls) {
    if (poll.id.isEmpty) {
      result.add(poll);
      continue;
    }
    if (seenIds.contains(poll.id)) {
      final idx = result.indexWhere((p) => p.id == poll.id);
      if (idx >= 0) {
        result[idx] =
            LunchPoll.merge(poll, result[idx]).withPollScopedVotes();
      }
      continue;
    }
    seenIds.add(poll.id);
    result.add(poll);
  }
  return result;
}

int _pollRecencyCompare(LunchPoll a, LunchPoll b) {
  final byRecency = b.recencyInstant.compareTo(a.recencyInstant);
  if (byRecency != 0) return byRecency;
  return b.id.compareTo(a.id);
}

DateTime? _newerDateTime(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isAfter(b) ? a : b;
}

DateTime? _createdAtFromObjectId(String id) {
  final raw = id.trim();
  if (raw.length != 24) return null;
  try {
    final seconds = int.parse(raw.substring(0, 8), radix: 16);
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true)
        .toLocal();
  } catch (_) {
    return null;
  }
}

List<LunchPoll> sortTodayPollsNewestFirst(List<LunchPoll> polls) {
  final copy = [...polls];
  copy.sort(_pollRecencyCompare);
  return copy;
}

void _upsertTodayPoll(Map<String, LunchPoll> byId, LunchPoll poll) {
  if (poll.id.isEmpty) return;
  final existing = byId[poll.id];
  // Keep per-poll myVote from the incoming row; only strip when merging shells
  // that intentionally omit votes would lose authoritative selection.
  byId[poll.id] = existing == null
      ? poll.withPollScopedVotes()
      : existing.applyServerSnapshot(poll).withPollScopedVotes();
}

class LunchTodayBundle {
  const LunchTodayBundle({required this.items, this.legacyPoll});

  final List<LunchPoll> items;
  final LunchPoll? legacyPoll;

  factory LunchTodayBundle.fromJson(dynamic raw) {
    if (raw is List) {
      final byId = <String, LunchPoll>{};
      for (final entry in raw.whereType<Map>()) {
        _upsertTodayPoll(
          byId,
          LunchPoll.fromJson(Map<String, dynamic>.from(entry)),
        );
      }
      return LunchTodayBundle(
        items: sortTodayPollsNewestFirst(
          byId.values.map((p) => p.withPollScopedVotes()).toList(),
        ),
      );
    }

    final m = _map(raw);
    final data = m['data'];
    final root = data is Map ? _map(data) : m;

    LunchMyVote? topVote;
    final mv = root['myVote'] ?? root['my_vote'] ?? root['userVote'];
    if (mv is Map) {
      topVote = LunchMyVote.fromJson(Map<String, dynamic>.from(mv));
    }

    final topResults = _parsePollOptions(
      root['results'] ?? root['resultCounts'] ?? root['voteCounts'],
    );
    final topOptions = _parsePollOptions(
      root['options'] ?? root['pollOptions'] ?? root['choices'],
    );

    LunchPoll? featured;
    final p = root['poll'];
    if (p is Map) {
      featured = LunchPoll.fromJson(Map<String, dynamic>.from(p));
    }

    final byId = <String, LunchPoll>{};
    for (final poll in _mapList(
      root,
      const [
        'items',
        'polls',
        'activePolls',
        'active_polls',
        'openPolls',
        'open_polls',
        'reactivatedPolls',
        'reactivated_polls',
      ],
    ).map(LunchPoll.fromJson)) {
      _upsertTodayPoll(byId, poll);
    }
    if (featured != null) {
      _upsertTodayPoll(byId, featured);
    }

    final featuredId = featured?.id ?? '';
    if (byId.length == 1) {
      final onlyId = byId.keys.first;
      byId[onlyId] = _applyTodayFeaturedShell(
        poll: byId[onlyId]!,
        topOptions: topOptions,
        topResults: topResults,
        topVote: topVote,
      );
    } else if (featuredId.isNotEmpty && byId.containsKey(featuredId)) {
      byId[featuredId] = _applyTodayFeaturedShell(
        poll: byId[featuredId]!,
        topOptions: topOptions,
        topResults: topResults,
        topVote: topVote,
      );
    } else if (byId.isEmpty && featured != null && featured.id.isNotEmpty) {
      byId[featured.id] = _applyTodayFeaturedShell(
        poll: featured.withoutMyVote(),
        topOptions: topOptions,
        topResults: topResults,
        topVote: topVote,
      );
    }

    final items = sortTodayPollsNewestFirst(
      byId.values.map((p) => p.withPollScopedVotes()).toList(),
    );

    return LunchTodayBundle(items: items, legacyPoll: featured);
  }
}

class LunchMenuBreakdownRow {
  const LunchMenuBreakdownRow({
    required this.label,
    required this.optionType,
    required this.votes,
    this.share = 0,
    this.voters = const [],
  });

  final String label;
  final String optionType;
  final int votes;
  final double share;
  final List<LunchOptionVoter> voters;

  LunchOptionKind get kind => lunchOptionKindFrom(optionType);

  factory LunchMenuBreakdownRow.fromJson(Map<String, dynamic> json) {
    final votes = parseOptionalInt(json['votes'] ?? json['voteCount'] ?? json['count']) ?? 0;
    final share = parseOptionalNum(json['share'] ?? json['percentage'])?.toDouble() ?? 0;
    return LunchMenuBreakdownRow(
      label: _str(json['label'] ?? json['menuItem'] ?? json['name'] ?? json['title']),
      optionType: _str(json['optionType'] ?? json['option_type'] ?? json['type']),
      votes: votes,
      share: share,
      voters: LunchOptionVoter.parseList(
        json['voters'] ?? json['voterNames'] ?? json['users'] ?? json['responses'],
      ),
    );
  }
}

class LunchEmployeeVoteRow {
  const LunchEmployeeVoteRow({
    required this.userId,
    required this.userName,
    required this.choice,
    required this.optionType,
    this.votedAt,
  });

  final String userId;
  final String userName;
  final String choice;
  final String optionType;
  final DateTime? votedAt;

  LunchOptionKind get kind => lunchOptionKindFrom(optionType);

  factory LunchEmployeeVoteRow.fromJson(Map<String, dynamic> json, {LunchPoll? poll}) {
    final user = json['user'] ?? json['employee'];
    String name = _str(
      json['userName'] ?? json['user_name'] ?? json['employeeName'] ?? json['name'],
    );
    String uid = _id(json['userId'] ?? json['user_id'] ?? json['employeeId']);
    if (user is Map) {
      final um = Map<String, dynamic>.from(user);
      if (name.isEmpty) name = _str(um['name']);
      if (uid.isEmpty) uid = _id(um['id'] ?? um['_id']);
    }

    var choice = _str(
      json['choice'] ??
          json['label'] ??
          json['optionLabel'] ??
          json['menuItem'] ??
          json['menu_item'],
    );
    var optionType = _str(json['optionType'] ?? json['option_type'] ?? json['type']);

    final optionObj = json['option'];
    if (optionObj is Map) {
      final om = Map<String, dynamic>.from(optionObj);
      if (choice.isEmpty) {
        choice = _str(om['label'] ?? om['name'] ?? om['title']);
      }
      if (optionType.isEmpty) {
        optionType = _str(om['optionType'] ?? om['option_type'] ?? om['type']);
      }
    }

    final optionId = _id(json['optionId'] ?? json['option_id'] ?? json['selectedOptionId']);
    if (poll != null && optionId.isNotEmpty) {
      for (final o in poll.mergedOptions) {
        if (o.id == optionId) {
          if (choice.isEmpty) choice = o.label;
          if (optionType.isEmpty) optionType = o.optionType;
          break;
        }
      }
    }

    return LunchEmployeeVoteRow(
      userId: uid,
      userName: name.isEmpty ? 'Unknown' : name,
      choice: choice,
      optionType: optionType,
      votedAt: _parseDateTime(
        json['votedAt'] ??
            json['voted_at'] ??
            json['voteTime'] ??
            json['vote_time'] ??
            json['timestamp'] ??
            json['createdAt'] ??
            json['created_at'] ??
            json['updatedAt'] ??
            json['updated_at'],
      ),
    );
  }
}

/// Admin order summary — `GET /api/lunch/polls/:id/summary`.
class LunchOrderSummary {
  const LunchOrderSummary({
    required this.poll,
    this.officeOrders = 0,
    this.personalCount = 0,
    this.totalVotes = 0,
    this.menuBreakdown = const [],
    this.employeeVotes = const [],
  });

  final LunchPoll poll;
  final int officeOrders;
  final int personalCount;
  final int totalVotes;
  final List<LunchMenuBreakdownRow> menuBreakdown;
  final List<LunchEmployeeVoteRow> employeeVotes;

  factory LunchOrderSummary.fromJson(dynamic raw, {LunchPoll? pollFallback}) {
    final m = _map(raw);
    final data = m['data'];
    final root = data is Map ? _map(data) : m;
    final inner = root['summary'] is Map ? _map(root['summary']) : root;
    final pollRaw = inner['poll'] ?? root['poll'] ?? pollFallback;
    var poll = pollRaw is Map
        ? LunchPoll.fromJson(Map<String, dynamic>.from(pollRaw))
        : pollFallback ?? LunchPoll(id: '', title: 'Lunch');

    if (poll.options.isEmpty &&
        pollFallback != null &&
        pollFallback.mergedOptions.isNotEmpty) {
      poll = pollFallback;
    }

    var breakdown = _mapList(
      inner['menuBreakdown'] ??
          inner['menu_breakdown'] ??
          inner['breakdown'] ??
          inner['options'],
      const ['items', 'rows'],
    ).map(LunchMenuBreakdownRow.fromJson).toList();

    var employees = _parseEmployeeVotes(
      inner['employeeVotes'] ??
          inner['employee_votes'] ??
          inner['employeeResponses'] ??
          inner['responses'] ??
          inner['votes'] ??
          inner['participants'] ??
          inner['balanceChanges'] ??
          inner['balance_changes'] ??
          root['employeeVotes'] ??
          root['employee_votes'] ??
          root['votes'] ??
          root['participants'] ??
          root['balanceChanges'] ??
          root['balance_changes'],
      poll,
    );

    if (employees.isEmpty && pollRaw is Map) {
      final pm = Map<String, dynamic>.from(pollRaw);
      employees = _parseEmployeeVotes(
        pm['employeeVotes'] ??
            pm['employee_votes'] ??
            pm['votes'] ??
            pm['responses'] ??
            pm['participants'] ??
            pm['balanceChanges'] ??
            pm['balance_changes'],
        poll,
      );
    }

    if (employees.isEmpty) {
      employees = _deriveEmployeeVotesFromPoll(poll);
    }

    if (employees.isEmpty && breakdown.isNotEmpty) {
      employees = _deriveEmployeeVotesFromBreakdown(breakdown);
    }

    var office = parseOptionalInt(
      inner['officeOrders'] ?? inner['office_orders'] ?? inner['officeMealCount'],
    );
    var personal = parseOptionalInt(
      inner['personalCount'] ?? inner['personal'] ?? inner['personalMealCount'],
    );
    var total = parseOptionalInt(
      inner['totalVotes'] ?? inner['total_votes'] ?? inner['total'],
    );

    // Derive from breakdown if counts missing.
    if (breakdown.isEmpty && poll.results.isNotEmpty) {
      breakdown = poll.results
          .map(
            (r) => LunchMenuBreakdownRow(
              label: r.label,
              optionType: r.optionType,
              votes: r.voteCount,
            ),
          )
          .toList();
    }

    int officeCount;
    int personalCountVal;
    int totalCount;

    if (office != null && personal != null && total != null) {
      officeCount = office;
      personalCountVal = personal;
      totalCount = total;
    } else {
      int off = 0, pers = 0, all = 0;
      for (final row in breakdown) {
        all += row.votes;
        switch (row.kind) {
          case LunchOptionKind.officeMenu:
            off += row.votes;
          case LunchOptionKind.personal:
            pers += row.votes;
          case LunchOptionKind.offAbsent:
          case LunchOptionKind.other:
            break;
        }
      }
      officeCount = office ?? off;
      personalCountVal = personal ?? pers;
      totalCount = total ?? (all > 0 ? all : employees.length);
    }

    // Compute share percentages if missing.
    final totalForShare = totalCount > 0
        ? totalCount
        : breakdown.fold<int>(0, (s, r) => s + r.votes);
    final normalizedBreakdown = breakdown.map((row) {
      if (row.share > 0) return row;
      final pct = totalForShare > 0 ? (row.votes / totalForShare) * 100 : 0.0;
      return LunchMenuBreakdownRow(
        label: row.label,
        optionType: row.optionType,
        votes: row.votes,
        share: pct,
        voters: row.voters,
      );
    }).toList();

    return LunchOrderSummary(
      poll: poll.id.isEmpty ? pollFallback ?? poll : poll,
      officeOrders: officeCount,
      personalCount: personalCountVal,
      totalVotes: totalCount,
      menuBreakdown: normalizedBreakdown,
      employeeVotes: employees,
    );
  }

  static List<LunchEmployeeVoteRow> deriveEmployeeVotes(LunchPoll poll) =>
      _deriveEmployeeVotesFromPoll(poll);

  static List<LunchEmployeeVoteRow> deriveEmployeeVotesFromBreakdown(
    List<LunchMenuBreakdownRow> breakdown,
  ) =>
      _deriveEmployeeVotesFromBreakdown(breakdown);

  static List<LunchEmployeeVoteRow> fromVoteHistoryRows(
    List<LunchVoteHistoryRow> rows, {
    String? pollId,
  }) {
    return rows
        .where((r) {
          if (pollId == null || pollId.isEmpty) return true;
          if (r.pollId == null || r.pollId!.isEmpty) return true;
          return r.pollId == pollId;
        })
        .map(
          (r) => LunchEmployeeVoteRow(
            userId: r.userId ?? '',
            userName: r.userName ?? 'Unknown',
            choice: r.menuItem ?? '',
            optionType: r.optionType ?? '',
            votedAt: r.votedAt,
          ),
        )
        .where((r) => r.userName != 'Unknown' || r.choice.isNotEmpty)
        .toList();
  }

  static List<LunchEmployeeVoteRow> _parseEmployeeVotes(
    dynamic raw,
    LunchPoll poll,
  ) {
    final rows = _mapList(raw, const ['items', 'rows', 'votes', 'data'])
        .map((m) => LunchEmployeeVoteRow.fromJson(m, poll: poll))
        .where((r) => r.userName != 'Unknown' || r.choice.isNotEmpty)
        .toList();
    return rows;
  }

  static List<LunchEmployeeVoteRow> _deriveEmployeeVotesFromPoll(LunchPoll poll) {
    final rows = <LunchEmployeeVoteRow>[];
    for (final opt in poll.mergedOptions) {
      for (final voter in opt.voters) {
        rows.add(
          LunchEmployeeVoteRow(
            userId: voter.userId ?? '',
            userName: voter.name,
            choice: opt.label,
            optionType: opt.optionType,
          ),
        );
      }
    }
    return rows;
  }

  static List<LunchEmployeeVoteRow> _deriveEmployeeVotesFromBreakdown(
    List<LunchMenuBreakdownRow> breakdown,
  ) {
    final rows = <LunchEmployeeVoteRow>[];
    for (final row in breakdown) {
      for (final voter in row.voters) {
        rows.add(
          LunchEmployeeVoteRow(
            userId: voter.userId ?? '',
            userName: voter.name,
            choice: row.label,
            optionType: row.optionType,
          ),
        );
      }
    }
    return rows;
  }
}

class LunchBalanceMe {
  const LunchBalanceMe({this.balance = 0, this.monthNetChange = 0, this.month});

  final num balance;
  final num monthNetChange;
  final String? month;

  factory LunchBalanceMe.fromJson(dynamic raw) {
    final m = _map(raw);
    final inner = m['data'] is Map ? _map(m['data']) : m;
    return LunchBalanceMe(
      balance: parseOptionalNum(inner['balance']) ?? 0,
      monthNetChange: parseOptionalNum(
        inner['monthNetChange'] ?? inner['month_net_change'],
      ) ?? 0,
      month: _str(inner['month']).isEmpty ? null : _str(inner['month']),
    );
  }
}

class LunchBalanceTransaction {
  const LunchBalanceTransaction({
    required this.amount,
    this.reason,
    this.type,
    this.createdAt,
    this.pollId,
  });

  final num amount;
  final String? reason;
  final String? type;
  final DateTime? createdAt;
  final String? pollId;

  factory LunchBalanceTransaction.fromJson(Map<String, dynamic> json) {
    return LunchBalanceTransaction(
      amount: parseOptionalNum(json['amount']) ?? 0,
      reason: _str(json['reason']).isEmpty ? null : _str(json['reason']),
      type: _str(json['type']).isEmpty ? null : _str(json['type']),
      createdAt: DateTime.tryParse(_str(json['createdAt'] ?? json['created_at'])),
      pollId: _id(json['pollId'] ?? json['poll_id']).isEmpty
          ? null
          : _id(json['pollId'] ?? json['poll_id']),
    );
  }
}

class LunchEmployeeBalance {
  const LunchEmployeeBalance({
    required this.userId,
    required this.userName,
    this.netChange = 0,
    this.balance = 0,
    this.hasExplicitNetChange = false,
  });

  final String userId;
  final String userName;
  final num netChange;
  final num balance;
  final bool hasExplicitNetChange;

  /// Net change for the selected date range (primary value for the employees table).
  num get periodNetChange {
    if (hasExplicitNetChange) return netChange;
    return balance;
  }

  /// Running account balance — only when distinct from [periodNetChange].
  num? get runningBalance {
    if (!hasExplicitNetChange) return null;
    if (balance == 0) return null;
    if (balance != netChange) return balance;
    return null;
  }

  factory LunchEmployeeBalance.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    var name = _str(json['userName'] ?? json['user_name'] ?? json['name']);
    var uid = _id(json['userId'] ?? json['user_id']);
    if (user is Map) {
      final um = Map<String, dynamic>.from(user);
      if (name.isEmpty) name = _str(um['name']);
      if (uid.isEmpty) uid = _id(um['id'] ?? um['_id']);
    }

    num? net = parseOptionalNum(
      json['netChange'] ??
          json['net_change'] ??
          json['monthNetChange'] ??
          json['month_net_change'] ??
          json['change'] ??
          json['periodChange'] ??
          json['period_change'] ??
          json['amount'],
    );
    num? total;

    final balRaw = json['balance'];
    if (balRaw is Map) {
      final bm = Map<String, dynamic>.from(balRaw);
      total = parseOptionalNum(
        bm['balance'] ?? bm['current'] ?? bm['total'] ?? bm['amount'],
      );
      net ??= parseOptionalNum(
        bm['netChange'] ??
            bm['net_change'] ??
            bm['monthNetChange'] ??
            bm['change'],
      );
    } else {
      total = parseOptionalNum(balRaw);
      if (net == null && total != null) {
        // Employees endpoint sometimes returns period change only as `balance`.
        net = total;
        total = parseOptionalNum(
          json['totalBalance'] ?? json['total_balance'] ?? json['currentBalance'],
        );
      }
    }

    return LunchEmployeeBalance(
      userId: uid,
      userName: name.isEmpty ? 'Unknown' : name,
      netChange: net ?? 0,
      balance: total ?? 0,
      hasExplicitNetChange: net != null,
    );
  }
}

class LunchVoteHistoryRow {
  const LunchVoteHistoryRow({
    required this.pollTitle,
    this.pollDate,
    this.menuItem,
    this.optionType,
    this.optionId,
    this.amount,
    this.userName,
    this.userId,
    this.pollId,
    this.votedAt,
  });

  final String pollTitle;
  final DateTime? pollDate;
  final String? menuItem;
  final String? optionType;
  final String? optionId;
  final num? amount;
  final String? userName;
  final String? userId;
  final String? pollId;
  final DateTime? votedAt;

  factory LunchVoteHistoryRow.fromJson(Map<String, dynamic> json) {
    final menu = _str(
      json['menuItem'] ??
          json['menu_item'] ??
          json['choice'] ??
          json['optionLabel'] ??
          json['label'],
    );
    final user = json['user'] ?? json['employee'];
    var userName = _str(json['userName'] ?? json['user_name']);
    var userId = _id(json['userId'] ?? json['user_id']);
    if (user is Map) {
      final um = Map<String, dynamic>.from(user);
      if (userName.isEmpty) userName = _str(um['name']);
      if (userId.isEmpty) userId = _id(um['id'] ?? um['_id']);
    }
    final optionObj = json['option'];
    var optionId = _id(
      json['optionId'] ??
          json['option_id'] ??
          json['selectedOptionId'] ??
          json['selected_option_id'],
    );
    if (optionId.isEmpty && optionObj is Map) {
      optionId = _id(optionObj['id'] ?? optionObj['_id']);
    }
    return LunchVoteHistoryRow(
      pollTitle: _str(json['pollTitle'] ?? json['poll_title'] ?? json['title'], 'Poll'),
      pollDate: DateTime.tryParse(_str(json['pollDate'] ?? json['poll_date'] ?? json['date'])),
      menuItem: menu.isEmpty ? null : menu,
      optionType: _str(json['optionType'] ?? json['option_type']).isEmpty
          ? null
          : _str(json['optionType'] ?? json['option_type']),
      optionId: optionId.isEmpty ? null : optionId,
      amount: parseOptionalNum(
        json['amount'] ?? json['balanceChange'] ?? json['balance_change'] ?? json['cost'],
      ),
      userName: userName.isEmpty ? null : userName,
      userId: userId.isEmpty ? null : userId,
      pollId: _id(json['pollId'] ?? json['poll_id']).isEmpty
          ? null
          : _id(json['pollId'] ?? json['poll_id']),
      votedAt: _parseDateTime(json['votedAt'] ?? json['voted_at']),
    );
  }
}

class LunchDashboardStats {
  const LunchDashboardStats({
    this.activePolls = 0,
    this.totalVotesToday = 0,
    this.totalEmployees = 0,
  });

  final int activePolls;
  final int totalVotesToday;
  final int totalEmployees;

  factory LunchDashboardStats.fromJson(dynamic raw) {
    final m = _map(raw);
    final inner = m['data'] is Map ? _map(m['data']) : m;
    return LunchDashboardStats(
      activePolls: parseOptionalInt(inner['activePolls'] ?? inner['active_polls']) ?? 0,
      totalVotesToday: parseOptionalInt(
        inner['totalVotesToday'] ?? inner['total_votes_today'],
      ) ?? 0,
      totalEmployees: parseOptionalInt(
        inner['totalEmployees'] ?? inner['total_employees'],
      ) ?? 0,
    );
  }
}
