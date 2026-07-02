/// Legal entity tokens — stripped from names and never used alone for matching.
const _legalTokens = {
  'private',
  'limited',
  'ltd',
  'pvt',
  'public',
  'proprietary',
  'partnership',
  'liability',
  'incorporated',
  'inc',
  'corporation',
  'corpn',
  'corp',
  'company',
  'co',
  'llp',
  'llc',
  'plc',
  'gmbh',
  'pty',
  'pte',
  'sdn',
  'bhd',
  'sa',
  'ag',
  'bv',
  'nv',
  'oy',
  'ab',
  'lp',
  'pllc',
  'se',
  'sons',
  'son',
  'bros',
  'brothers',
  'associates',
  'association',
};

/// Common business descriptors — kept in the name but low priority for scoring.
const _genericDescriptorTokens = {
  'group',
  'holdings',
  'holding',
  'enterprises',
  'enterprise',
  'international',
  'technologies',
  'technology',
  'solutions',
  'services',
  'systems',
  'global',
  'industries',
  'industry',
  'manufacturing',
  'trading',
  'traders',
  'consulting',
  'consultancy',
  'logistics',
  'pharmaceutical',
  'pharmaceuticals',
};

/// Legal suffix phrases stripped during normalization (longest first).
const _legalSuffixPhrases = [
  'private limited',
  'pvt ltd',
  'pvt limited',
  'proprietary limited',
  'public limited',
  'limited liability partnership',
  'limited liability company',
  'limited partnership',
  'limited',
  'ltd',
  'incorporated',
  'inc',
  'corporation',
  'corpn',
  'corp',
  'company',
  'co',
  'llp',
  'llc',
  'plc',
  'gmbh',
  'pty',
  'pte',
  'sdn',
  'bhd',
  'sa',
  'ag',
  'bv',
  'nv',
  'oy',
  'ab',
  'lp',
  'pllc',
  'se',
  'sons',
  'son',
  'bros',
  'brothers',
  'associates',
  'association',
];

/// A CRM company ranked as similar to OCR / typed text.
class CompanyNameMatchCandidate {
  const CompanyNameMatchCandidate({
    required this.id,
    required this.name,
    required this.score,
  });

  final String id;
  final String name;
  final int score;
}

/// OCR company match: auto-pick only when very confident; otherwise suggest similar names.
class CompanyNameMatchResult {
  const CompanyNameMatchResult({
    this.autoSelectId,
    this.suggestions = const [],
    this.ocrCompanyName,
  });

  final String? autoSelectId;
  final List<CompanyNameMatchCandidate> suggestions;
  final String? ocrCompanyName;

  bool get hasSuggestions => suggestions.isNotEmpty;
}

/// Cleans noisy OCR company strings before matching.
String cleanOcrCompanyName(String name) {
  var s = name.trim();
  if (s.isEmpty) return s;

  s = s.split(RegExp(r'[\n\r]+')).first.trim();

  final trailingNoise = RegExp(
    r'\s+(head\s+office|branch(\s+office)?|regd\.?\s+office|registered\s+office|corporate\s+office|hq)$',
    caseSensitive: false,
  );
  s = s.replaceFirst(trailingNoise, '').trim();

  return s;
}

String _preprocessCompanyName(String name) {
  var s = cleanOcrCompanyName(name).toLowerCase();
  if (s.isEmpty) return s;

  s = s.replaceAll(RegExp(r'\s*&\s*'), ' and ');
  s = s.replaceAll('.', '');
  s = s.replaceAll(RegExp(r'[,&®™()\-_/\\+|]'), ' ');
  s = s.replaceAll("'", '').replaceAll('"', '');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

  const prefixes = ['m/s', 'ms', 'messrs', 'the'];
  var prefixChanged = true;
  while (prefixChanged) {
    prefixChanged = false;
    for (final prefix in prefixes) {
      if (s == prefix) {
        s = '';
        prefixChanged = true;
        break;
      }
      final head = '$prefix ';
      if (s.startsWith(head)) {
        s = s.substring(head.length).trim();
        prefixChanged = true;
      }
    }
  }

  return s
      .split(' ')
      .map(_expandCompanyToken)
      .where((t) => t.isNotEmpty)
      .join(' ');
}

/// Normalizes company names for fuzzy matching (OCR vs CRM database).
String normalizeCompanyNameForMatch(String name) {
  var s = _preprocessCompanyName(name);
  if (s.isEmpty) return s;

  var changed = true;
  while (changed) {
    changed = false;
    for (final suffix in _legalSuffixPhrases) {
      if (s == suffix) {
        s = '';
        changed = true;
        break;
      }
      final tail = ' $suffix';
      if (s.endsWith(tail)) {
        s = s.substring(0, s.length - tail.length).trim();
        changed = true;
      }
      final head = '$suffix ';
      if (s.startsWith(head)) {
        s = s.substring(head.length).trim();
        changed = true;
      }
    }
  }

  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _expandCompanyToken(String token) {
  const expansions = {
    'intl': 'international',
    'int': 'international',
    'mfg': 'manufacturing',
    'dept': 'department',
    'assoc': 'associates',
    'assn': 'association',
    'pharm': 'pharmaceutical',
    'pharma': 'pharmaceutical',
    'telecom': 'telecommunications',
    'tech': 'technology',
    'mfr': 'manufacturer',
    'mfrs': 'manufacturers',
    'dev': 'development',
    'govt': 'government',
    'natl': 'national',
    'mgmt': 'management',
    'svcs': 'services',
    'svc': 'services',
    'engr': 'engineering',
    'ind': 'industries',
    'indust': 'industries',
  };
  return expansions[token] ?? token;
}

List<String> _orderedSignificantTokens(String text) {
  const stop = {'and', 'of', 'the', 'for', 'in', 'at', 'a', 'an', 'to', 'by'};
  return text
      .split(' ')
      .map((t) => t.trim())
      .where((t) => t.length >= 2 && !stop.contains(t))
      .toList();
}

Set<String> _significantTokens(String normalized) {
  return _orderedSignificantTokens(normalized).toSet();
}

Set<String> _primaryTokens(String normalized) {
  return _significantTokens(normalized)
      .where(
        (t) => !_legalTokens.contains(t) && !_genericDescriptorTokens.contains(t),
      )
      .toSet();
}

Set<String> _secondaryTokens(String normalized) {
  return _significantTokens(normalized)
      .where(
        (t) =>
            !_legalTokens.contains(t) && _genericDescriptorTokens.contains(t),
      )
      .toSet();
}

String _singularizeToken(String token) {
  if (token.length > 3 && token.endsWith('ies')) {
    return '${token.substring(0, token.length - 3)}y';
  }
  if (token.length > 3 && token.endsWith('s')) {
    return token.substring(0, token.length - 1);
  }
  return token;
}

bool _tokenFuzzyEqual(String a, String b) {
  if (a == b) return true;

  final aSing = _singularizeToken(a);
  final bSing = _singularizeToken(b);
  if (aSing == bSing) return true;

  if (aSing.length >= 5 && bSing.startsWith(aSing)) return true;
  if (bSing.length >= 5 && aSing.startsWith(bSing)) return true;

  return _isSpellingMatch(aSing, bSing);
}

int _levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  final m = a.length;
  final n = b.length;
  var previous = List<int>.generate(n + 1, (j) => j);
  var current = List<int>.filled(n + 1, 0);

  for (var i = 1; i <= m; i++) {
    current[0] = i;
    for (var j = 1; j <= n; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      final deletion = current[j - 1] + 1;
      final insertion = previous[j] + 1;
      final substitution = previous[j - 1] + cost;
      current[j] = deletion < insertion
          ? (deletion < substitution ? deletion : substitution)
          : (insertion < substitution ? insertion : substitution);
    }
    final swap = previous;
    previous = current;
    current = swap;
  }
  return previous[n];
}

double _spellingSimilarity(String a, String b) {
  if (a.isEmpty || b.isEmpty) return 0;
  if (a == b) return 1;
  final maxLen = a.length > b.length ? a.length : b.length;
  return 1 - (_levenshtein(a, b) / maxLen);
}

int _maxAllowedEdits(int length) {
  if (length <= 4) return 1;
  if (length <= 7) return 2;
  return 3;
}

bool _isSpellingMatch(String a, String b) {
  if (a.isEmpty || b.isEmpty) return false;
  if (a.length < 3 || b.length < 3) return false;

  final longer = a.length >= b.length ? a : b;
  final shorter = a.length >= b.length ? b : a;
  if (longer.length - shorter.length > _maxAllowedEdits(longer.length)) {
    return false;
  }

  final distance = _levenshtein(a, b);
  if (distance > _maxAllowedEdits(longer.length)) return false;

  return _spellingSimilarity(a, b) >= 0.72;
}

int _bestTokenSpellingScore(String token, Set<String> candidates) {
  if (token.length < 3) return 0;
  var best = 0;
  for (final candidate in candidates) {
    if (!_isSpellingMatch(token, candidate)) continue;
    final similarity = _spellingSimilarity(
      _singularizeToken(token),
      _singularizeToken(candidate),
    );
    final points = (18 + (similarity * 12)).round();
    if (points > best) best = points;
  }
  return best;
}

int _wholeNameSpellingScore(String a, String b) {
  if (a.length < 4 || b.length < 4) return 0;
  if (!_isSpellingMatch(a, b)) return 0;
  final similarity = _spellingSimilarity(a, b);
  return (30 + (similarity * 20)).round();
}

bool _hasSpellingHit(Set<String> targetTokens, Set<String> companyTokens) {
  for (final token in targetTokens) {
    if (token.length < 3) continue;
    for (final companyToken in companyTokens) {
      if (_isSpellingMatch(token, companyToken)) return true;
    }
  }
  return false;
}

bool _tokenInSet(String token, Set<String> tokens) {
  for (final candidate in tokens) {
    if (_tokenFuzzyEqual(token, candidate)) return true;
  }
  return false;
}

String _acronymFromPreprocessedName(String name) {
  final tokens = _orderedSignificantTokens(_preprocessCompanyName(name))
      .where((t) => !_legalTokens.contains(t))
      .toList();
  if (tokens.length < 2) return '';
  return tokens.map((t) => t[0]).join();
}

bool _isLegalOnlyName(String name) {
  final tokens = _orderedSignificantTokens(_preprocessCompanyName(name));
  if (tokens.isEmpty) return true;
  return tokens.every(_legalTokens.contains);
}

int _matchScore({
  required String normTarget,
  required Set<String> targetPrimary,
  required Set<String> targetSecondary,
  required String normCompany,
  required Set<String> companyPrimary,
  required Set<String> companySecondary,
}) {
  if (normTarget.isNotEmpty && normTarget == normCompany) return 1000;

  var score = 0;

  for (final token in targetPrimary) {
    if (_tokenInSet(token, companyPrimary)) {
      score += 30;
    } else {
      final spellingScore = _bestTokenSpellingScore(token, companyPrimary);
      if (spellingScore > 0) {
        score += spellingScore;
      } else if (_tokenInSet(token, companySecondary)) {
        score += 8;
      } else if (_tokenInSet(token, _significantTokens(normCompany))) {
        score += 4;
      }
    }
  }

  for (final token in targetSecondary) {
    if (_tokenInSet(token, companySecondary) ||
        _tokenInSet(token, companyPrimary)) {
      score += 3;
    }
  }

  if (normTarget.length >= 4 && normCompany.length >= 4) {
    final shorter = normTarget.length <= normCompany.length
        ? normTarget
        : normCompany;
    final longer = normTarget.length <= normCompany.length
        ? normCompany
        : normTarget;
    if (longer.startsWith(shorter) || longer == shorter) {
      score += shorter.length * 2;
    } else if (shorter.length >= 6 && longer.contains(shorter)) {
      score += shorter.length;
    } else {
      score += _wholeNameSpellingScore(shorter, longer);
    }
  }

  return score;
}

bool _allPrimaryTokensMatch(
  Set<String> targetPrimary,
  Set<String> companyPrimary,
  Set<String> companyDistinctive,
) {
  if (targetPrimary.isEmpty) return false;
  final companyTokens =
      companyPrimary.isNotEmpty ? companyPrimary : companyDistinctive;
  return targetPrimary.every((t) => _tokenInSet(t, companyTokens));
}

String? _pickAutoSelectId(List<CompanyNameMatchCandidate> ranked) {
  if (ranked.isEmpty) return null;

  final best = ranked.first;
  if (best.score >= 1000) return best.id;

  if (ranked.length == 1 && best.score >= 45) return best.id;

  if (ranked.length >= 2) {
    final second = ranked[1];
    final gap = best.score - second.score;
    if (best.score >= 60 && gap >= 25) return best.id;
    if (best.score >= 90 && gap >= 15) return best.id;
  }

  return null;
}

/// Rank CRM companies by similarity to OCR / typed company name.
CompanyNameMatchResult rankCompaniesByName(
  List<({String id, String name})> companies,
  String? companyName, {
  int maxSuggestions = 5,
}) {
  final target = cleanOcrCompanyName(companyName ?? '');
  if (target.isEmpty) {
    return const CompanyNameMatchResult();
  }

  final normTarget = normalizeCompanyNameForMatch(target);
  final lowerTarget = target.toLowerCase();
  final targetPrimary = _primaryTokens(normTarget);
  final targetSecondary = _secondaryTokens(normTarget);
  final targetDistinctive = targetPrimary.isNotEmpty
      ? targetPrimary
      : _significantTokens(normTarget).where((t) => !_legalTokens.contains(t)).toSet();

  if (targetDistinctive.isEmpty || _isLegalOnlyName(target)) {
    return CompanyNameMatchResult(ocrCompanyName: target);
  }

  final targetIsGenericOnly = targetPrimary.isEmpty &&
      targetDistinctive.every(_genericDescriptorTokens.contains);

  final scores = <String, ({String name, int score})>{};

  void addScore(String id, String name, int score) {
    if (score <= 0) return;
    final existing = scores[id];
    if (existing == null || score > existing.score) {
      scores[id] = (name: name, score: score);
    }
  }

  for (final c in companies) {
    final normC = normalizeCompanyNameForMatch(c.name);
    final companyPrimary = _primaryTokens(normC);
    final companySecondary = _secondaryTokens(normC);
    final companyDistinctive = companyPrimary.isNotEmpty
        ? companyPrimary
        : _significantTokens(normC).where((t) => !_legalTokens.contains(t)).toSet();
    if (companyDistinctive.isEmpty) continue;

    if (normTarget.isNotEmpty && normC == normTarget) {
      addScore(c.id, c.name, 1000);
      continue;
    }

    if (c.name.trim().toLowerCase() == lowerTarget) {
      addScore(c.id, c.name, 999);
      continue;
    }

    final effectiveTargetPrimary =
        targetPrimary.isNotEmpty ? targetPrimary : targetDistinctive;
    final effectiveCompanyPrimary =
        companyPrimary.isNotEmpty ? companyPrimary : companyDistinctive;

    final hasPrimaryHit = effectiveTargetPrimary
        .any((t) => _tokenInSet(t, effectiveCompanyPrimary));
    final hasDescriptorHit = targetDistinctive.any(
      (t) =>
          _tokenInSet(t, companySecondary) ||
          _tokenInSet(t, effectiveCompanyPrimary) ||
          _tokenInSet(t, _significantTokens(normC)),
    );
    final hasSpellingHit = _hasSpellingHit(
      effectiveTargetPrimary,
      effectiveCompanyPrimary,
    );
    if (!hasPrimaryHit && !hasDescriptorHit && !hasSpellingHit) continue;

    var score = _matchScore(
      normTarget: normTarget,
      targetPrimary: effectiveTargetPrimary,
      targetSecondary: targetSecondary,
      normCompany: normC,
      companyPrimary: effectiveCompanyPrimary,
      companySecondary: companySecondary,
    );

    if (_allPrimaryTokensMatch(
      effectiveTargetPrimary,
      companyPrimary,
      companyDistinctive,
    )) {
      score += 15;
    }

    if (score >= 20 || (targetIsGenericOnly && score >= 8)) {
      addScore(c.id, c.name, score);
    }
  }

  // Spelling-only pass for OCR typos that token rules may miss.
  for (final c in companies) {
    if (scores.containsKey(c.id)) continue;

    final normC = normalizeCompanyNameForMatch(c.name);
    if (normC.isEmpty) continue;

    final companyPrimary = _primaryTokens(normC);
    final companyDistinctive = companyPrimary.isNotEmpty
        ? companyPrimary
        : _significantTokens(normC).where((t) => !_legalTokens.contains(t)).toSet();
    if (companyDistinctive.isEmpty) continue;

    final effectiveTargetPrimary =
        targetPrimary.isNotEmpty ? targetPrimary : targetDistinctive;
    final effectiveCompanyPrimary =
        companyPrimary.isNotEmpty ? companyPrimary : companyDistinctive;

    var spellScore = 0;
    for (final token in effectiveTargetPrimary) {
      spellScore += _bestTokenSpellingScore(token, effectiveCompanyPrimary);
    }
    spellScore += _wholeNameSpellingScore(normTarget, normC);

    if (spellScore >= 22) {
      addScore(c.id, c.name, spellScore);
    }
  }

  if (normTarget.length >= 2 && normTarget.length <= 6) {
    for (final c in companies) {
      if (_acronymFromPreprocessedName(c.name) == normTarget) {
        addScore(c.id, c.name, 850);
      }
    }
  }

  final ranked = scores.entries
      .map(
        (e) => CompanyNameMatchCandidate(
          id: e.key,
          name: e.value.name,
          score: e.value.score,
        ),
      )
      .toList()
    ..sort((a, b) => b.score.compareTo(a.score));

  final suggestions = ranked.take(maxSuggestions).toList();

  String? autoSelectId = targetIsGenericOnly ? null : _pickAutoSelectId(ranked);

  if (autoSelectId != null &&
      targetPrimary.isNotEmpty &&
      ranked.isNotEmpty &&
      ranked.first.score < 800) {
    final winner = companies.where((c) => c.id == autoSelectId).firstOrNull;
    if (winner != null) {
      final normC = normalizeCompanyNameForMatch(winner.name);
      final companyPrimary = _primaryTokens(normC);
      final companyDistinctive = companyPrimary.isNotEmpty
          ? companyPrimary
          : _significantTokens(normC).where((t) => !_legalTokens.contains(t)).toSet();
      if (!_allPrimaryTokensMatch(targetPrimary, companyPrimary, companyDistinctive)) {
        autoSelectId = null;
      }
    }
  }

  return CompanyNameMatchResult(
    autoSelectId: autoSelectId,
    suggestions: suggestions,
    ocrCompanyName: target,
  );
}

/// High-confidence auto match only. Prefer [rankCompaniesByName] for OCR flows.
String? matchCompanyIdByName(
  List<({String id, String name})> companies,
  String? companyName,
) {
  return rankCompaniesByName(companies, companyName).autoSelectId;
}
