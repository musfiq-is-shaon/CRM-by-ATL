import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/rbac_page_keys.dart';
import '../../data/models/rbac_model.dart';
import '../../data/repositories/rbac_repository.dart';
import 'auth_provider.dart';

enum RbacLoadStatus { idle, loading, loaded, error }

class RbacState {
  const RbacState({
    this.status = RbacLoadStatus.idle,
    this.me,
    this.errorMessage,
  });

  /// Empty state for comparisons before first RBAC emission.
  static const empty = RbacState();

  final RbacLoadStatus status;
  final RbacMe? me;
  final String? errorMessage;

  RbacState copyWith({
    RbacLoadStatus? status,
    RbacMe? me,
    String? errorMessage,
  }) {
    return RbacState(
      status: status ?? this.status,
      me: me ?? this.me,
      errorMessage: errorMessage,
    );
  }

  bool get isReady => status == RbacLoadStatus.loaded && me != null;
}

class RbacNotifier extends StateNotifier<RbacState> {
  RbacNotifier(this._repository) : super(const RbacState());

  final RbacRepository _repository;
  bool _loadBusy = false;

  /// Single in-flight request — avoids discarding a successful response when a newer
  /// call fails first (sequence-based loads left [me] null and hid all modules).
  ///
  /// [silent]: no transition to `loading`, and on success does **not** notify listeners
  /// if permissions are unchanged — avoids rebuilding [ShellPage] / [IndexedStack] every poll.
  Future<void> load({bool silent = false}) async {
    if (_loadBusy) return;
    _loadBusy = true;
    final previousMe = state.me;
    if (!silent) {
      state = state.copyWith(
        status: RbacLoadStatus.loading,
        errorMessage: null,
      );
    }
    try {
      final me = await _repository.fetchMe();
      if (silent) {
        final unchanged =
            previousMe != null &&
            me.sameUiAccessAs(previousMe) &&
            state.status == RbacLoadStatus.loaded;
        if (!unchanged) {
          state = RbacState(status: RbacLoadStatus.loaded, me: me);
        }
      } else {
        state = RbacState(status: RbacLoadStatus.loaded, me: me);
      }
    } catch (e) {
      if (!silent) {
        state = RbacState(
          status: RbacLoadStatus.error,
          me: previousMe,
          errorMessage: e.toString(),
        );
      }
    } finally {
      _loadBusy = false;
    }
  }

  void clear() {
    state = const RbacState();
  }
}

final rbacProvider = StateNotifierProvider<RbacNotifier, RbacState>((ref) {
  return RbacNotifier(ref.watch(rbacRepositoryProvider));
});

/// Convenience: current RBAC payload when loaded.
final rbacMeProvider = Provider<RbacMe?>((ref) {
  return ref.watch(rbacProvider).me;
});

/// Hash of nav + effective access levels — changes when a module goes `user` → `admin`
/// (nav keys may stay the same). Watch this in tab screens so IndexedStack children rebuild
/// and refetch paths run after [loadedTabsProvider] is cleared in the shell.
final rbacAccessDigestProvider = Provider<int>((ref) {
  final me = ref.watch(rbacMeProvider);
  if (me == null) return 0;
  var h = me.navPageKeys.length;
  for (final k in me.navPageKeys) {
    h = Object.hash(h, k);
  }
  final keys = me.effective.keys.toList()..sort();
  for (final k in keys) {
    h = Object.hash(h, k, me.effective[k]);
  }
  return h;
});

/// Global JWT `admin` **or** RBAC `admin` for [pageKey] (full module scope per API).
final rbacModuleAdminProvider = Provider.family<bool, String>((ref, pageKey) {
  if (ref.watch(isAdminProvider)) return true;
  return ref.watch(rbacMeProvider)?.isModuleAdmin(pageKey) ?? false;
});

/// Leave calendar / all / team admin paths: JWT admin, Leaves RBAC admin, or HR nav.
final leaveManagementElevatedProvider = Provider<bool>((ref) {
  if (ref.watch(isAdminProvider)) return true;
  final me = ref.watch(rbacMeProvider);
  if (me == null) return false;
  if (me.isModuleAdmin(RbacPageKey.leaves)) return true;
  if (me.hasNav(RbacPageKey.hr)) return true;
  return false;
});

/// Edit org company profile on Profile screen.
final companyProfileEditAllowedProvider = Provider<bool>((ref) {
  if (ref.watch(isAdminProvider)) return true;
  return ref.watch(rbacMeProvider)?.isModuleAdmin(RbacPageKey.companies) ??
      false;
});

/// Dashboard **Add Deal** / **Add Lead** quick action: same rule as the Deals bottom tab
/// ([ShellPage] uses [RbacMe.hasNav] for non–JWT users), plus [hasModuleAccess].
/// JWT admins: follow `effective.sales` once loaded (default show until then).
final dashboardQuickActionSalesProvider = Provider<bool>((ref) {
  if (ref.watch(isAdminProvider)) {
    return ref.watch(rbacMeProvider)?.hasModuleAccess(RbacPageKey.sales) ??
        true;
  }
  final me = ref.watch(rbacMeProvider);
  if (me == null) return false;
  return me.hasNav(RbacPageKey.sales) && me.hasModuleAccess(RbacPageKey.sales);
});

/// Dashboard **Add Expense** quick action: same rule as the Expenses bottom tab
/// ([ShellPage] uses [RbacMe.hasNav] for non–JWT users), plus [hasModuleAccess].
/// JWT admins: follow `effective.expenses` once loaded (default show until then).
final dashboardQuickActionExpensesProvider = Provider<bool>((ref) {
  if (ref.watch(isAdminProvider)) {
    return ref.watch(rbacMeProvider)?.hasModuleAccess(RbacPageKey.expenses) ??
        true;
  }
  final me = ref.watch(rbacMeProvider);
  if (me == null) return false;
  return me.hasNav(RbacPageKey.expenses) &&
      me.hasModuleAccess(RbacPageKey.expenses);
});

/// Dashboard tasks quick action and task sections: `tasks` has no bottom tab — use
/// [RbacMe.hasModuleAccess] only. JWT admins respect `effective.tasks` when loaded.
final dashboardTasksModuleProvider = Provider<bool>((ref) {
  if (ref.watch(isAdminProvider)) {
    return ref.watch(rbacMeProvider)?.hasModuleAccess(RbacPageKey.tasks) ??
        true;
  }
  return ref.watch(rbacMeProvider)?.hasModuleAccess(RbacPageKey.tasks) ?? false;
});
