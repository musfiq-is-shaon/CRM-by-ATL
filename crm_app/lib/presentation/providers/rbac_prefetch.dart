import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/rbac_page_keys.dart';
import '../../data/models/rbac_model.dart';
import 'auth_provider.dart';
import 'company_provider.dart';
import 'user_provider.dart';

/// Fetches shared lookup lists (companies, users) whenever RBAC grants a module
/// that uses them in forms or filters — not only when the Contacts tab is visible.
Future<void> prefetchCrmLookupData(WidgetRef ref, RbacMe? me) async {
  if (me == null) return;

  final isAdmin = ref.read(isAdminProvider);

  final needCompanies = me.canNavCompanies ||
      me.hasNav(RbacPageKey.sales) ||
      me.hasNav(RbacPageKey.tasks) ||
      me.hasNav(RbacPageKey.expenses) ||
      me.canNavContacts;

  final needUsers = me.hasNav(RbacPageKey.sales) ||
      me.hasNav(RbacPageKey.tasks) ||
      me.hasNav(RbacPageKey.expenses) ||
      me.hasNav(RbacPageKey.hr) ||
      isAdmin;

  await Future.wait([
    if (needCompanies) ref.read(companiesProvider.notifier).loadCompanies(),
    if (needUsers) ref.read(usersProvider.notifier).loadUsers(),
  ]);
}
