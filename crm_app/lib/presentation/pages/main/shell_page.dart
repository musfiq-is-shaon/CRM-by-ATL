import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/rbac_page_keys.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/contact_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../providers/rbac_prefetch.dart';
import '../../providers/rbac_provider.dart'
    show rbacProvider, RbacState, RbacLoadStatus, rbacAccessDigestProvider;
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

/// Keeps each shell tab’s subtree alive when paged off-screen (parity with former [IndexedStack]).
class _KeepAliveShellTab extends StatefulWidget {
  const _KeepAliveShellTab({required this.child});

  final Widget child;

  @override
  State<_KeepAliveShellTab> createState() => _KeepAliveShellTabState();
}

class _KeepAliveShellTabState extends State<_KeepAliveShellTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

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

  /// Swipe between tabs (aligned with [tabIds] order).
  PageController? _pageController;
  String? _pageControllerTabKey;

  final GlobalKey _bottomNavBarKey = GlobalKey();

  /// User is sliding along the bottom nav (show range highlight).
  bool _navBarDragging = false;

  /// Navbar preview while dragging — updates immediately; [PageView] follows on release.
  int? _navBarPreviewIndex;

  /// Avoid rebuilding shell tab children when only unrelated providers change.
  String? _tabPagesCacheKey;
  List<Widget>? _tabPagesCache;

  void _disposePageController() {
    _pageController?.dispose();
    _pageController = null;
    _pageControllerTabKey = null;
  }

  void _ensurePageController(List<String> tabIds, int selectedTab) {
    final key = tabIds.join('|');
    if (_pageControllerTabKey == key && _pageController != null) return;
    _pageController?.dispose();
    _pageControllerTabKey = key;
    _pageController = PageController(
      initialPage: selectedTab.clamp(0, tabIds.length - 1),
    );
  }

  ScrollPhysics get _tabSwipePhysics {
    // iOS: bouncy overscroll; Android: standard clamped paging.
    final parent = defaultTargetPlatform == TargetPlatform.iOS
        ? const BouncingScrollPhysics()
        : const ClampingScrollPhysics();
    return PageScrollPhysics(parent: parent);
  }

  /// Commits the active tab (provider + loads). Used when the [PageView] lands on a page.
  void _commitTab(List<String> tabIds, int index) {
    final clamped = index.clamp(0, tabIds.length - 1);
    if (ref.read(selectedTabProvider) != clamped) {
      ref.read(selectedTabProvider.notifier).state = clamped;
    }
    _loadTabData(tabIds, clamped);
  }

  /// Updates navbar preview from finger x only — does not move [PageView].
  void _updateNavBarPreviewFromDrag(DragUpdateDetails details, int tabCount) {
    final box =
        _bottomNavBarKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final local = box.globalToLocal(details.globalPosition);
    final dx = local.dx.clamp(0.0, box.size.width);
    final cellW = box.size.width / tabCount;
    final i = (dx / cellW).floor().clamp(0, tabCount - 1);
    if (_navBarPreviewIndex != i) {
      setState(() {
        _navBarPreviewIndex = i;
      });
    }
  }

  /// After releasing the nav-bar drag, jump [PageView] to [targetIndex] (same as
  /// tap — no scrolling through pages in between). Navbar pill still settles via
  /// [AnimatedPositioned].
  void _jumpPageToNavPreview(int targetIndex, int tabCount) {
    final c = _pageController;
    if (c == null) return;
    final target = targetIndex.clamp(0, tabCount - 1);
    c.jumpToPage(target);
    if (!mounted) return;
    setState(() {
      _navBarPreviewIndex = null;
    });
  }

  void _switchToTab(int index, List<String> tabIds, int currentSelected) {
    final clamped = index.clamp(0, tabIds.length - 1);
    if (_navBarPreviewIndex != null) {
      setState(() {
        _navBarPreviewIndex = null;
      });
    }
    final c = _pageController;
    if (c != null && c.hasClients && c.page != null) {
      if (c.page!.round() == clamped) return;
    } else if (clamped == currentSelected) {
      return;
    }
    // Tap: jump straight to the tab (no scrolling through pages in between).
    // Navbar pill still animates via [AnimatedPositioned] on index change.
    _pageController?.jumpToPage(clamped);
  }

  void _onNavBarHorizontalDragStart(
    DragStartDetails details,
    int tabCount,
    int selectedTab,
  ) {
    final box =
        _bottomNavBarKey.currentContext?.findRenderObject() as RenderBox?;
    var anchor = (_pageController?.page?.round() ?? selectedTab).clamp(
      0,
      tabCount - 1,
    );
    if (box != null && box.hasSize) {
      final local = box.globalToLocal(details.globalPosition);
      final dx = local.dx.clamp(0.0, box.size.width);
      final cellW = box.size.width / tabCount;
      anchor = (dx / cellW).floor().clamp(0, tabCount - 1);
    }
    setState(() {
      _navBarDragging = true;
      _navBarPreviewIndex = anchor;
    });
  }

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
    _disposePageController();
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
            child: _KeepAliveShellTab(child: pageFor(id)),
          ),
        )
        .toList();
  }

  /// Same tab order + ids → reuse widget list so [PageView] does not churn.
  List<Widget> _memoizedTabPages(List<String> ids) {
    final key = ids.join('|');
    if (_tabPagesCacheKey == key && _tabPagesCache != null) {
      return _tabPagesCache!;
    }
    _tabPagesCacheKey = key;
    _tabPagesCache = _tabPages(ids);
    return _tabPagesCache!;
  }

  List<_ShellNavItem> _shellNavItems(List<String> ids) {
    return ids.map((id) {
      switch (id) {
        case _kDashboard:
          return const _ShellNavItem(
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard,
            label: 'Dashboard',
          );
        case _kSales:
          return const _ShellNavItem(
            icon: Icons.trending_up_outlined,
            selectedIcon: Icons.trending_up,
            label: 'Deals',
          );
        case _kExpenses:
          return const _ShellNavItem(
            icon: Icons.receipt_long_outlined,
            selectedIcon: Icons.receipt_long,
            label: 'Expense',
          );
        case _kContacts:
          return const _ShellNavItem(
            icon: Icons.people_outline,
            selectedIcon: Icons.people,
            label: 'Contacts',
          );
        case _kMore:
          return const _ShellNavItem(
            icon: Icons.menu_outlined,
            selectedIcon: Icons.menu,
            label: 'More',
          );
        default:
          return const _ShellNavItem(
            icon: Icons.circle_outlined,
            selectedIcon: Icons.circle_outlined,
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
        final loadAttendance =
            me == null ||
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
    final navItems = _shellNavItems(tabIds);

    ref.listen<RbacState>(rbacProvider, (previous, next) {
      final prevIds = _tabIds(previous ?? RbacState.empty);
      final nextIds = _tabIds(next);
      final nextIdSet = nextIds.toSet();
      ref
          .read(loadedTabsProvider.notifier)
          .update((s) => s.intersection(nextIdSet));
      if (prevIds.length != nextIds.length) {
        final cur = ref.read(selectedTabProvider);
        if (cur >= nextIds.length) {
          ref.read(selectedTabProvider.notifier).state = 0;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _pageController?.jumpToPage(0);
          });
        }
      }
      if (next.status == RbacLoadStatus.loaded && next.me != null) {
        prefetchCrmLookupData(ref, next.me);
        final prevMe = previous?.me;
        if (prevMe == null || !next.me!.sameUiAccessAs(prevMe)) {
          // Allow module data refetch when only `effective` changes (e.g. contacts user→admin).
          ref.read(loadedTabsProvider.notifier).state = {};
          final idx = ref
              .read(selectedTabProvider)
              .clamp(0, nextIds.length - 1);
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

    _ensurePageController(tabIds, selectedTab);

    return Scaffold(
      backgroundColor: AppThemeColors.backgroundColor(context),
      body: RepaintBoundary(
        child: PageView(
          key: ValueKey<String>(tabIds.join('|')),
          controller: _pageController,
          physics: _tabSwipePhysics,
          onPageChanged: (index) {
            _commitTab(tabIds, index);
          },
          children: pages,
        ),
      ),
      bottomNavigationBar: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (details) =>
            _onNavBarHorizontalDragStart(details, tabIds.length, selectedTab),
        onHorizontalDragUpdate: (details) {
          _updateNavBarPreviewFromDrag(details, tabIds.length);
        },
        onHorizontalDragEnd: (_) {
          final preview =
              _navBarPreviewIndex?.clamp(0, tabIds.length - 1) ??
              selectedTab.clamp(0, tabIds.length - 1);
          setState(() {
            _navBarDragging = false;
          });
          _jumpPageToNavPreview(preview, tabIds.length);
        },
        onHorizontalDragCancel: () {
          setState(() {
            _navBarDragging = false;
            _navBarPreviewIndex = null;
          });
        },
        child: AnimatedBuilder(
          animation: _pageController!,
          builder: (context, _) {
            final c = _pageController!;
            final pageIdx = c.hasClients && c.page != null
                ? c.page!.round().clamp(0, tabIds.length - 1)
                : selectedTab;
            // While dragging, pill follows [_navBarPreviewIndex]; after release it
            // matches [pageIdx] once [_jumpPageToNavPreview] clears the preview.
            final navIdx = _navBarPreviewIndex != null
                ? _navBarPreviewIndex!.clamp(0, tabIds.length - 1)
                : pageIdx;
            return _ShellNavigationBar(
              key: _bottomNavBarKey,
              items: navItems,
              selectedIndex: navIdx,
              dragging: _navBarDragging,
              onDestinationSelected: (index) {
                _switchToTab(index, tabIds, selectedTab);
              },
            );
          },
        ),
      ),
    );
  }
}

/// One bottom-nav destination (icons + label) for [_ShellNavigationBar].
class _ShellNavItem {
  const _ShellNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Material 3–style bar with an animated sliding highlight during drag.
class _ShellNavigationBar extends StatelessWidget {
  const _ShellNavigationBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.dragging,
    required this.onDestinationSelected,
  });

  final List<_ShellNavItem> items;
  final int selectedIndex;
  final bool dragging;
  final ValueChanged<int> onDestinationSelected;

  static const double _pillRadius = 22;

  /// Horizontal inset so the pill sits inside one cell (does not span start→end).
  static const double _pillHorizontalInset = 5;

  /// Matches [CRMCard]: tonal surface, outline, [AppElevation] shadows.
  /// Dragging adds a light primary tint (same language as card ink / chips).
  BoxDecoration _highlightDecoration(
    BuildContext context, {
    required bool isDragging,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = cs.outlineVariant.withValues(alpha: 0.65);
    final shadows = isDark
        ? AppElevation.cardDark(cs.primary)
        : AppElevation.cardLight;
    final base = cs.surfaceContainerHigh;
    final fill = isDragging
        ? Color.alphaBlend(
            cs.primary.withValues(alpha: isDark ? 0.14 : 0.09),
            base,
          )
        : base;
    final border = isDragging
        ? Border.all(color: cs.primary.withValues(alpha: 0.38), width: 1.25)
        : Border.all(color: borderColor);

    return BoxDecoration(
      borderRadius: BorderRadius.circular(_pillRadius),
      color: fill,
      border: border,
      boxShadow: shadows,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final navTheme = Theme.of(context).navigationBarTheme;
    final n = items.length;
    if (n == 0) return const SizedBox.shrink();

    return Material(
      elevation: navTheme.elevation ?? 3,
      surfaceTintColor: cs.surfaceTint,
      color: navTheme.backgroundColor ?? cs.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 80,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final cellW = w / n;
              final idx = selectedIndex.clamp(0, n - 1);
              final hlLeft = idx * cellW + _pillHorizontalInset;
              final hlWidth = cellW - 2 * _pillHorizontalInset;

              // Faster while dragging (follows finger); softer settle when not.
              final posDuration = dragging
                  ? const Duration(milliseconds: 160)
                  : const Duration(milliseconds: 340);
              final decorDuration = dragging
                  ? const Duration(milliseconds: 180)
                  : const Duration(milliseconds: 320);

              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  AnimatedPositioned(
                    duration: posDuration,
                    curve: Curves.easeOutCubic,
                    left: hlLeft,
                    top: 5,
                    bottom: 5,
                    width: hlWidth,
                    child: AnimatedContainer(
                      duration: decorDuration,
                      curve: Curves.easeOutCubic,
                      decoration: _highlightDecoration(
                        context,
                        isDragging: dragging,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  Row(
                    children: List.generate(n, (i) {
                      final item = items[i];
                      final sel = i == selectedIndex;
                      return Expanded(
                        child: InkWell(
                          onTap: () => onDestinationSelected(i),
                          borderRadius: BorderRadius.circular(_pillRadius),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              style: Theme.of(context).textTheme.labelSmall!
                                  .copyWith(
                                    fontSize: 12,
                                    color: sel
                                        ? cs.onSurface
                                        : cs.onSurfaceVariant,
                                    fontWeight: sel
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 220),
                                    switchInCurve: Curves.easeOutCubic,
                                    switchOutCurve: Curves.easeOutCubic,
                                    transitionBuilder: (child, anim) {
                                      return FadeTransition(
                                        opacity: anim,
                                        child: child,
                                      );
                                    },
                                    child: Icon(
                                      sel ? item.selectedIcon : item.icon,
                                      key: ValueKey<String>('${i}_${sel}_icon'),
                                      size: 24,
                                      color: sel
                                          ? cs.primary
                                          : cs.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
