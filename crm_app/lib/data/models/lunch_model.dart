import '../../core/json_parse.dart';

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
  if (s.contains('office') || s == 'yes' || s == 'menu') {
    return LunchOptionKind.officeMenu;
  }
  if (s.contains('personal') || s == 'own') {
    return LunchOptionKind.personal;
  }
  if (s.contains('off') || s == 'no' || s.contains('absent')) {
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
        json['votes'] ?? json['voteCount'] ?? json['count'] ?? json['vote_count'],
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
      votedAt: DateTime.tryParse(_str(json['votedAt'] ?? json['voted_at'])),
    );
  }
}

class LunchPoll {
  const LunchPoll({
    required this.id,
    required this.title,
    this.date,
    this.costAmount,
    this.allowVoteChange = true,
    this.endTime,
    this.status = 'active',
    this.options = const [],
    this.myVote,
    this.results = const [],
  });

  final String id;
  final String title;
  final DateTime? date;
  final num? costAmount;
  final bool allowVoteChange;
  final String? endTime;
  final String status;
  final List<LunchPollOption> options;
  final LunchMyVote? myVote;
  final List<LunchPollOption> results;

  bool get isActive => status.toLowerCase() == 'active';
  bool get isClosed => status.toLowerCase() == 'closed';
  bool get isCancelled => status.toLowerCase() == 'cancelled';

  /// Options merged with live result counts + voter avatars.
  List<LunchPollOption> get mergedOptions {
    if (options.isEmpty) return results;
    if (results.isEmpty) return options;

    final byId = {for (final r in results) if (r.id.isNotEmpty) r.id: r};
    final byLabel = {for (final r in results) if (r.label.isNotEmpty) r.label: r};

    return options.map((o) {
      final r = (o.id.isNotEmpty ? byId[o.id] : null) ??
          (o.label.isNotEmpty ? byLabel[o.label] : null);
      if (r == null) return o;
      return o.copyWith(
        voteCount: r.voteCount > 0 ? r.voteCount : o.voteCount,
        voters: r.voters.isNotEmpty ? r.voters : o.voters,
      );
    }).toList();
  }

  int get totalVoteCount =>
      mergedOptions.fold<int>(0, (sum, o) => sum + o.voteCount);

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
    if (secondary == null) return primary;
    return LunchPoll(
      id: primary.id.isNotEmpty ? primary.id : secondary.id,
      title: primary.title.isNotEmpty ? primary.title : secondary.title,
      date: primary.date ?? secondary.date,
      costAmount: primary.costAmount ?? secondary.costAmount,
      allowVoteChange: primary.allowVoteChange,
      endTime: primary.endTime ?? secondary.endTime,
      status: primary.status.isNotEmpty ? primary.status : secondary.status,
      options: primary.options.isNotEmpty ? primary.options : secondary.options,
      results: primary.results.isNotEmpty ? primary.results : secondary.results,
      myVote: primary.myVote ?? secondary.myVote,
    );
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
    );
  }

  Map<String, dynamic> toCreateJson() => {
    if (date != null) 'date': _dateOnly(date!),
    'title': title,
    if (costAmount != null) 'costAmount': costAmount,
    'allowVoteChange': allowVoteChange,
    if (endTime != null && endTime!.isNotEmpty) 'endTime': endTime,
    'options': options.map((o) => o.toCreateJson()).toList(),
  };

  static String _dateOnly(DateTime d) {
    final l = d.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
  }
}

class LunchTodayBundle {
  const LunchTodayBundle({required this.items, this.legacyPoll});

  final List<LunchPoll> items;
  final LunchPoll? legacyPoll;

  factory LunchTodayBundle.fromJson(dynamic raw) {
    if (raw is List) {
      return LunchTodayBundle(
        items: raw
            .whereType<Map>()
            .map((e) => LunchPoll.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
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

    LunchPoll? legacy;
    final p = root['poll'];
    if (p is Map) legacy = LunchPoll.fromJson(Map<String, dynamic>.from(p));

    final shellWithTop = LunchPoll(
      id: '',
      title: 'Lunch',
      options: topOptions,
      results: topResults,
      myVote: topVote,
    );
    if (legacy != null) {
      legacy = LunchPoll.merge(legacy, shellWithTop);
    } else if (topOptions.isNotEmpty || topResults.isNotEmpty || topVote != null) {
      legacy = shellWithTop;
    }

    LunchPoll enrich(LunchPoll poll) {
      var merged = legacy != null ? LunchPoll.merge(poll, legacy) : poll;
      if (merged.mergedOptions.isEmpty && topOptions.isNotEmpty) {
        merged = LunchPoll.merge(
          merged,
          LunchPoll(id: merged.id, title: merged.title, options: topOptions, results: topResults),
        );
      }
      return merged;
    }

    var items = _mapList(root, const ['items', 'polls']).map(LunchPoll.fromJson).map(enrich).toList();

    if (items.isEmpty && legacy != null) {
      items = [legacy];
    }

    return LunchTodayBundle(items: items, legacyPoll: legacy);
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
      votedAt: DateTime.tryParse(
        _str(json['votedAt'] ?? json['voted_at'] ?? json['createdAt'] ?? json['created_at']),
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
  });

  final String userId;
  final String userName;
  final num netChange;
  final num balance;

  factory LunchEmployeeBalance.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    var name = _str(json['userName'] ?? json['user_name'] ?? json['name']);
    var uid = _id(json['userId'] ?? json['user_id']);
    if (user is Map) {
      final um = Map<String, dynamic>.from(user);
      if (name.isEmpty) name = _str(um['name']);
      if (uid.isEmpty) uid = _id(um['id'] ?? um['_id']);
    }
    return LunchEmployeeBalance(
      userId: uid,
      userName: name.isEmpty ? 'Unknown' : name,
      netChange: parseOptionalNum(json['netChange'] ?? json['net_change']) ?? 0,
      balance: parseOptionalNum(json['balance']) ?? 0,
    );
  }
}

class LunchVoteHistoryRow {
  const LunchVoteHistoryRow({
    required this.pollTitle,
    this.pollDate,
    this.menuItem,
    this.optionType,
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
    return LunchVoteHistoryRow(
      pollTitle: _str(json['pollTitle'] ?? json['poll_title'] ?? json['title'], 'Poll'),
      pollDate: DateTime.tryParse(_str(json['pollDate'] ?? json['poll_date'] ?? json['date'])),
      menuItem: menu.isEmpty ? null : menu,
      optionType: _str(json['optionType'] ?? json['option_type']).isEmpty
          ? null
          : _str(json['optionType'] ?? json['option_type']),
      amount: parseOptionalNum(
        json['amount'] ?? json['balanceChange'] ?? json['balance_change'] ?? json['cost'],
      ),
      userName: userName.isEmpty ? null : userName,
      userId: userId.isEmpty ? null : userId,
      pollId: _id(json['pollId'] ?? json['poll_id']).isEmpty
          ? null
          : _id(json['pollId'] ?? json['poll_id']),
      votedAt: DateTime.tryParse(_str(json['votedAt'] ?? json['voted_at'])),
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
