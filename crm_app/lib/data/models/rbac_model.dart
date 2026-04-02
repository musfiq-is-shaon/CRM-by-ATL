import '../../core/constants/rbac_page_keys.dart';

/// Response from `GET /api/rbac/me`.
class RbacMe {
  RbacMe({
    required this.navPageKeys,
    required this.effective,
  });

  /// Keys the user may open in navigation (sidebar / app tabs).
  final Set<String> navPageKeys;

  /// Per-module access: `none` | `user` | `admin`.
  final Map<String, String> effective;

  factory RbacMe.fromJson(Map<String, dynamic> json) {
    final navRaw = json['navPageKeys'] ?? json['nav_page_keys'];
    final nav = <String>{};
    if (navRaw is List) {
      for (final e in navRaw) {
        final s = e?.toString();
        if (s != null && s.isNotEmpty) nav.add(s);
      }
    }

    final effRaw = json['effective'];
    final effective = <String, String>{};
    if (effRaw is Map) {
      effRaw.forEach((k, v) {
        final key = k?.toString();
        if (key == null || key.isEmpty) return;
        effective[key] = v?.toString() ?? 'none';
      });
    }

    return RbacMe(navPageKeys: nav, effective: effective);
  }

  bool hasNav(String pageKey) => navPageKeys.contains(pageKey);

  /// Bottom-nav **Contacts** tab and contact CRUD — requires `contacts`, not `companies`.
  /// Company-only RBAC is for sales/KAM flows; it must not show the Contacts tab.
  bool get canNavContacts => hasNav(RbacPageKey.contacts);

  /// Companies module (e.g. deals filters, KAM scope) — separate from the Contacts tab.
  bool get canNavCompanies => hasNav(RbacPageKey.companies);

  String? accessFor(String pageKey) => effective[pageKey];

  bool hasModuleAccess(String pageKey) {
    final a = accessFor(pageKey);
    if (a == null) return hasNav(pageKey);
    return a != 'none';
  }

  bool isModuleAdmin(String pageKey) => accessFor(pageKey) == 'admin';
}
