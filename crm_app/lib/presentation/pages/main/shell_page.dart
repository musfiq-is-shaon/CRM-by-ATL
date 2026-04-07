import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/rbac_page_keys.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/contact_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../providers/rbac_prefetch.dart';
import '../../providers/rbac_provider.dart'
    show
        rbacProvider,
        RbacState,
        RbacLoadStatus,
        rbacAccessDigestProvider;
import '../../providers/auth_provider.dart';
import '../../providers/sale_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/renewal_provider.dart';
import '../../providers/task_provider.dart';
import '../contacts/contacts_list_page.dart';
import '../dashboard/dashboard_page.dart';
import '../expenses/expenses_list_page.dart';
import '../sales/sales_list_page.dart';
import 'more_page.dart';

final selectedTabProvider = StateProvider<int>((ref) => 0);

/// Which shell tabs have had data loaded at least once (by tab id).
final loadedTabsProvider = StateProvider<Set<String>>((ref) => {});

class ShellPage extends ConsumerStatefulWidget {
  const ShellPage({super.key});

  @override
  ConsumerState<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends ConsumerState<ShellPage>
    with WidgetsBindingObserver {
  static const _kDashboard = 'dashboard';
  static const _kSales = 'sales';
  static const _kExpenses = 'expenses';
  static const _kContacts = 'contacts';
  static const _kMore = 'more';

  Timer? _rbacForegroundPollTimer;

  /// Avoid rebuilding [IndexedStack] children when only unrelated providers change.
  String? _tabPagesCacheKey;
  List<Widget>? _tabPagesCache;

  void _startRbacForegroundPolling() {
    _rbacForegroundPollTimer?.cancel();
    // Immediate tick so we are not idle until the first [periodic] fire.
    scheduleMicrotask(() {
      if (!mounted) return;
      ref.read(rbacProvider.notifier).load(silent: true);
    });
    _rbacForegroundPollTimer = Timer.periodic(
      AppConstants.rbacForegroundPollInterval,
      (_) {
        if (!mounted) return;
        ref.read(rbacProvider.notifier).load(silent: true);
      },
    );
  }

  void _stopRbacForegroundPolling() {
    _rbacForegroundPollTimer?.cancel();
    _rbacForegroundPollTimer = null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedTabProvider.notifier).state = 0;
      final rbac = ref.read(rbacProvider);
      final ids = _tabIds(rbac);
      _loadTabData(ids, 0);
      _startRbacForegroundPolling();
    });
  }

  @override
  void dispose() {
    _stopRbacForegroundPolling();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _stopRbacForegroundPolling();
      case AppLifecycleState.resumed:
        _startRbacForegroundPolling();
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          // Permissions may change on the server while the app is backgrounded.
          await ref.read(rbacProvider.notifier).load(silent: true);
          if (!mounted) return;
          final rbac = ref.read(rbacProvider);
          final ids = _tabIds(rbac);
          final idx = ref.read(selectedTabProvider).clamp(0, ids.length - 1);
          _loadTabData(ids, idx);
        });
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  List<String> _tabIds(RbacState rbac) {
    final me = rbac.me;
    final jwtGlobalAdmin = ref.read(authProvider).user?.isAdmin ?? false;
    final ids = <String>[_kDashboard];

    // Global JWT admin: full bottom nav (API may still send explicit RBAC only).
    if (jwtGlobalAdmin) {
      ids
        ..add(_kSales)
        ..add(_kExpenses)
        ..add(_kContacts);
    } else if (me != null) {
      if (me.hasNav(RbacPageKey.sales)) ids.add(_kSales);
      if (me.hasNav(RbacPageKey.expenses)) ids.add(_kExpenses);
      if (me.canNavContacts) ids.add(_kContacts);
    }

    ids.add(_kMore);
    return ids;
  }

  List<Widget> _tabPages(List<String> ids) {
    Widget pageFor(String id) {
      switch (id) {
        case _kDashboard:
          return DashboardPage();
        case _kSales:
          return SalesListPage();
        case _kExpenses:
          return ExpensesListPage();
        case _kContacts:
          return ContactsListPage();
        case _kMore:
          return MorePage();
        default:
          return const SizedBox.shrink();
      }
    }

    return ids
        .map(
          (id) => KeyedSubtree(
            key: ValueKey<String>('shell_tab_$id'),
            child: pageFor(id),
          ),
        )
        .toList();
  }

  /// Same tab order + ids → reuse widget list so [IndexedStack] does not churn.
  List<Widget> _memoizedTabPages(List<String> ids) {
    final key = ids.join('|');
    if (_tabPagesCacheKey == key && _tabPagesCache != null) {
      return _tabPagesCache!;
    }
    _tabPagesCacheKey = key;
    _tabPagesCache = _tabPages(ids);
    return _tabPagesCache!;
  }

  List<NavigationDestination> _destinations(List<String> ids) {
    return ids.map((id) {
      switch (id) {
        case _kDashboard:
          return const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          );
        case _kSales:
          return const NavigationDestination(
            icon: Icon(Icons.trending_up_outlined),
            selectedIcon: Icon(Icons.trending_up),
            label: 'Deals',
          );
        case _kExpenses:
          return const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Expense',
          );
        case _kContacts:
          return const NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Contacts',
          );
        case _kMore:
          return const NavigationDestination(
            icon: Icon(Icons.menu_outlined),
            selectedIcon: Icon(Icons.menu),
            label: 'More',
          );
        default:
          return const NavigationDestination(
            icon: Icon(Icons.circle_outlined),
            label: '',
          );
      }
    }).toList();
  }

  void _loadTabData(List<String> tabIds, int index) {
    if (index < 0 || index >= tabIds.length) return;
    final id = tabIds[index];
    final me = ref.read(rbacProvider).me;

    if (id == _kDashboard) {
      prefetchCrmLookupData(ref, me);
      ref.read(notificationsProvider.notifier).load(silent: true);
      final uid = ref.read(currentUserIdProvider)?.trim();
      if (uid != null && uid.isNotEmpty) {
        final loadAttendance = me == null ||
            me.hasNav(RbacPageKey.attendance) ||
            me.hasNav(RbacPageKey.hr);
        if (loadAttendance) {
          ref.read(attendanceProvider.notifier).loadToday();
        }
      }
      if (me == null) return;
      if (me.hasNav(RbacPageKey.sales)) {
        ref.read(salesProvider.notifier).loadSales();
      }
      if (me.hasNav(RbacPageKey.tasks)) {
        ref.read(tasksProvider.notifier).loadTasks();
      }
      if (me.canNavContacts) {
        ref.read(contactsProvider.notifier).loadContacts();
      }
      return;
    }

    if (id == _kMore) {
      // Refetch every visit; `loadedTabs` must not skip this.
      ref.read(rbacProvider.notifier).load(silent: true);
      return;
    }

    final loaded = ref.read(loadedTabsProvider);
    if (loaded.contains(id)) return;

    ref.read(loadedTabsProvider.notifier).update((s) => {...s, id});

    switch (id) {
      case _kSales:
        ref.read(salesProvider.notifier).loadSales();
        ref.read(ordersProvider.notifier).loadOrders();
        ref.read(renewalsProvider.notifier).loadRenewals();
        break;
      case _kContacts:
        ref.read(contactsProvider.notifier).loadContacts();
        break;
      case _kExpenses:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild only when RBAC *permissions* change (digest) or JWT admin changes — not on
    // every [RbacState] update (e.g. `loading`), which was flashing the whole shell.
    ref.watch(rbacAccessDigestProvider);
    ref.watch(authProvider.select((a) => a.user?.isAdmin ?? false));

    final rbacState = ref.read(rbacProvider);
    final tabIds = _tabIds(rbacState);
    final pages = _memoizedTabPages(tabIds);
    final destinations = _destinations(tabIds);

    ref.listen<RbacState>(rbacProvider, (previous, next) {
      final prevIds = _tabIds(previous ?? RbacState.empty);
      final nextIds = _tabIds(next);
      final nextIdSet = nextIds.toSet();
      ref.read(loadedTabsProvider.notifier).update(
            (s) => s.intersection(nextIdSet),
          );
      if (prevIds.length != nextIds.length) {
        final cur = ref.read(selectedTabProvider);
        if (cur >= nextIds.length) {
          ref.read(selectedTabProvider.notifier).state = 0;
        }
      }
      if (next.status == RbacLoadStatus.loaded && next.me != null) {
        prefetchCrmLookupData(ref, next.me);
        final prevMe = previous?.me;
        if (prevMe == null || !next.me!.sameUiAccessAs(prevMe)) {
          // Allow module data refetch when only `effective` changes (e.g. contacts user→admin).
          ref.read(loadedTabsProvider.notifier).state = {};
          final idx =
              ref.read(selectedTabProvider).clamp(0, nextIds.length - 1);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _loadTabData(nextIds, idx);
          });
        }
      }
    });

    final rawIndex = ref.watch(selectedTabProvider);
    final selectedTab = rawIndex.clamp(0, tabIds.length - 1);
    if (rawIndex != selectedTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(selectedTabProvider.notifier).state = selectedTab;
      });
    }

    ref.listen<int>(selectedTabProvider, (previous, next) {
      final clamped = next.clamp(0, tabIds.length - 1);
      _loadTabData(tabIds, clamped);
    });

    return Scaffold(
      backgroundColor: AppThemeColors.backgroundColor(context),
      body: RepaintBoundary(
        child: IndexedStack(index: selectedTab, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) {
          ref.read(selectedTabProvider.notifier).state = index;
          _loadTabData(tabIds, index);
        },
        destinations: destinations,
      ),
    );
  }
}
