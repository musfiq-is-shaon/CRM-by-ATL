import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/rbac_page_keys.dart';
import '../../providers/auth_provider.dart';
import '../../providers/rbac_provider.dart';

/// Team reconciliation (review / approve / reject): **global JWT admin** or **RBAC**
/// `effective.attendance == admin` from `GET /api/rbac/me`.
bool canManageAttendanceReconciliations(WidgetRef ref) {
  if (ref.watch(authProvider).user?.isAdmin == true) return true;
  return ref.watch(rbacModuleAdminProvider(RbacPageKey.attendance));
}
