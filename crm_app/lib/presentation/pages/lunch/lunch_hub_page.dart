import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme_colors.dart';
import '../../providers/lunch_provider.dart';
import 'lunch_employees_page.dart';
import 'lunch_my_lunch_page.dart';
import 'lunch_order_summary_page.dart';
import 'lunch_polls_admin_page.dart';

class LunchHubPage extends ConsumerStatefulWidget {
  const LunchHubPage({super.key});

  @override
  ConsumerState<LunchHubPage> createState() => _LunchHubPageState();
}

class _LunchHubPageState extends ConsumerState<LunchHubPage>
    with TickerProviderStateMixin {
  TabController? _tabs;

  void _syncTabController(int length) {
    if (_tabs != null && _tabs!.length == length) return;
    final previous = _tabs?.index ?? 0;
    _tabs?.dispose();
    _tabs = TabController(
      length: length,
      vsync: this,
      initialIndex: previous.clamp(0, length - 1),
    );
  }

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(lunchAdminProvider);
    final bg = AppThemeColors.backgroundColor(context);
    final tabCount = isAdmin ? 4 : 1;
    _syncTabController(tabCount);

    if (!isAdmin) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppThemeColors.appBarTitle(context, 'Lunch'),
        body: const LunchMyLunchPage(),
      );
    }

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
            Tab(text: 'Order Summary'),
            Tab(text: 'Employees'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs!,
        children: const [
          LunchMyLunchPage(),
          LunchPollsAdminPage(),
          LunchOrderSummaryPage(),
          LunchEmployeesPage(),
        ],
      ),
    );
  }
}
