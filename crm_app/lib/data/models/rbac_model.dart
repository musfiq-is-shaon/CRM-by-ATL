import '../../core/constants/rbac_page_keys.dart';

/// Response from `GET /api/rbac/me`.
class RbacMe {
  RbacMe({required this.navPageKeys, required this.effective});

  /// Keys the user may open in navigation (sidebar / app tabs).
  final Set<String> navPageKeys;

  /// Per-module access: `none` | `user` | `admin`.
  final Map<String, String> effective;

  static String _normKey(String? k) {
    if (k == null) return '';
    return k.trim().toLowerCase();
  }

  static String _normAccess(String? v) {
    final s = (v ?? 'none').toString().trim().toLowerCase();
    if (s == 'admin' || s == 'user') return s;
    return 'none';
  }

  factory RbacMe.fromJson(Map<String, dynamic> json) {
    final navRaw = json['navPageKeys'] ?? json['nav_page_keys'];
    final nav = <String>{};
    if (navRaw is List) {
      for (final e in navRaw) {
        if (e is Map) {
          final pk = e['pageKey'] ?? e['page_key'] ?? e['key'];
          final s = _normKey(pk?.toString());
          if (s.isNotEmpty) nav.add(s);
          continue;
        }
        final s = _normKey(e?.toString());
        if (s.isNotEmpty) nav.add(s);
      }
    }

    final effRaw = json['effective'];
    final effective = <String, String>{};
    if (effRaw is Map) {
      effRaw.forEach((k, v) {
        final key = _normKey(k?.toString());
        if (key.isEmpty) return;
        effective[key] = _normAccess(v?.toString());
      });
    }

    // Some backends only populate `effective`; infer nav from non-none access.
    if (nav.isEmpty) {
      for (final e in effective.entries) {
        if (e.value != 'none') nav.add(e.key);
      }
    }

    return RbacMe(navPageKeys: nav, effective: effective);
  }

  bool hasNav(String pageKey) => navPageKeys.contains(_normKey(pageKey));

  /// Bottom-nav **Contacts** tab and contact CRUD — requires `contacts`, not `companies`.
  /// Company-only RBAC is for sales/KAM flows; it must not show the Contacts tab.
  bool get canNavContacts => hasNav(RbacPageKey.contacts);

  /// Companies module (e.g. deals filters, KAM scope) — separate from the Contacts tab.
  bool get canNavCompanies => hasNav(RbacPageKey.companies);

  String? accessFor(String pageKey) => effective[_normKey(pageKey)];

  bool hasModuleAccess(String pageKey) {
    final a = accessFor(pageKey);
    if (a == null) return hasNav(pageKey);
    return a != 'none';
  }

  bool isModuleAdmin(String pageKey) => accessFor(pageKey) == 'admin';

  /// True if any module grants RBAC `admin` (not JWT — use with [isModuleAdmin] per key).
  bool get hasAnyRbacModuleAdmin => effective.values.any((v) => v == 'admin');

  /// Whether nav + effective permissions match (for detecting UI-impacting RBAC changes).
  bool sameUiAccessAs(RbacMe? other) {
    if (other == null) return false;
    if (navPageKeys.length != other.navPageKeys.length) return false;
    if (!navPageKeys.containsAll(other.navPageKeys)) return false;
    if (effective.length != other.effective.length) return false;
    for (final e in effective.entries) {
      if (other.effective[e.key] != e.value) return false;
    }
    for (final k in other.effective.keys) {
      if (!effective.containsKey(k)) return false;
    }
    return true;
  }
}
