/// Canonical `pageKey` values from `GET /api/rbac/me` and `/api/rbac/pages`
/// (must match the backend CRM Flask API).
class RbacPageKey {
  RbacPageKey._();

  static const String sales = 'sales';
  static const String tasks = 'tasks';
  static const String expenses = 'expenses';
  static const String contacts = 'contacts';
  static const String companies = 'companies';
  static const String leaves = 'leaves';
  static const String hr = 'hr';
  static const String attendance = 'attendance';
}
