import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../../providers/lunch_provider.dart';
import '../../widgets/loading_widget.dart';
import 'lunch_employees_page.dart';
import 'lunch_my_lunch_page.dart';
import 'lunch_order_summary_page.dart';
import 'lunch_polls_admin_page.dart';
import 'lunch_settings_page.dart';

/// Builds [child] only after its tab has been selected at least once.
class _DeferredTabLoad extends StatefulWidget {
  const _DeferredTabLoad({
    required this.active,
    required this.child,
  });

  final bool active;
  final Widget child;

  @override
  State<_DeferredTabLoad> createState() => _DeferredTabLoadState();
}

class _DeferredTabLoadState extends State<_DeferredTabLoad> {
  bool _mounted = false;

  @override
  Widget build(BuildContext context) {
    if (widget.active) _mounted = true;
    // Inactive unmounted tabs must be zero-size — IndexedStack sizes to the
    // largest child and a tall skeleton bloated the lunch hub.
    if (!_mounted) {
      if (!widget.active) return const SizedBox.shrink();
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: ListSkeletonLoader(itemCount: 3, shrinkWrap: true),
      );
    }
    return widget.child;
  }
}

class LunchHubPage extends ConsumerStatefulWidget {
  const LunchHubPage({super.key});

  @override
  ConsumerState<LunchHubPage> createState() => _LunchHubPageState();
}

class _LunchHubPageState extends ConsumerState<LunchHubPage>
    with TickerProviderStateMixin {
  TabController? _tabs;
  int? _lastTabIndex;

  void _onTabChanged() {
    if (_tabs == null || _tabs!.indexIsChanging) return;
    final idx = _tabs!.index;
    if (idx == 0 && _lastTabIndex != null && _lastTabIndex != 0) {
      ref.read(lunchProvider.notifier).refreshTodayPollsIfStale();
    }
    _lastTabIndex = idx;
    setState(() {});
  }

  void _syncTabController(int length) {
    if (_tabs != null && _tabs!.length == length) return;
    final previous = _tabs?.index ?? 0;
    _tabs?.removeListener(_onTabChanged);
    _tabs?.dispose();
    _tabs = TabController(
      length: length,
      vsync: this,
      initialIndex: previous.clamp(0, length - 1),
    )..addListener(_onTabChanged);
    _lastTabIndex = _tabs!.index;
  }

  @override
  void dispose() {
    _tabs?.removeListener(_onTabChanged);
    _tabs?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(lunchAdminProvider);
    final bg = AppThemeColors.backgroundColor(context);
    const adminTabCount = 5;
    _syncTabController(isAdmin ? adminTabCount : 1);

    if (!isAdmin) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppThemeColors.appBarTitle(context, 'Lunch'),
        body: const LunchMyLunchPage(),
      );
    }

    final tabIndex = _tabs!.index;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppThemeColors.appBarTitle(
        context,
        'Lunch',
        bottom: TabBar(
          controller: _tabs!,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'My Lunch'),
            Tab(text: 'Polls'),
            Tab(text: 'Summary'),
            Tab(text: 'Balances'),
            Tab(text: 'Settings'),
          ],
        ),
      ),
      body: IndexedStack(
        index: tabIndex,
        children: [
          const LunchMyLunchPage(),
          _DeferredTabLoad(
            active: tabIndex == 1,
            child: const LunchPollsAdminPage(),
          ),
          _DeferredTabLoad(
            active: tabIndex == 2,
            child: const LunchOrderSummaryPage(),
          ),
          _DeferredTabLoad(
            active: tabIndex == 3,
            child: const LunchEmployeesPage(),
          ),
          _DeferredTabLoad(
            active: tabIndex == 4,
            child: const LunchSettingsPage(),
          ),
        ],
      ),
    );
  }
}
