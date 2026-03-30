import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/sale_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/contact_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/notifications_provider.dart';
import '../dashboard/dashboard_page.dart';
import '../sales/sales_list_page.dart';
import '../expenses/expenses_list_page.dart';
import '../contacts/contacts_list_page.dart';
import '../../../core/theme/app_theme_colors.dart';
import 'more_page.dart';

final selectedTabProvider = StateProvider<int>((ref) => 0);

// Track which tabs have been loaded
final loadedTabsProvider = StateProvider<Set<int>>((ref) => {});

class ShellPage extends ConsumerStatefulWidget {
  const ShellPage({super.key});

  @override
  ConsumerState<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends ConsumerState<ShellPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Load dashboard data immediately after login
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Always land on Dashboard (IndexedStack can keep another tab from last session).
      ref.read(selectedTabProvider.notifier).state = 0;
      _loadTabData(0);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Pick up check-in/out done on another device (same account) from API.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(attendanceProvider.notifier).loadToday();
      });
    }
  }

  void _loadTabData(int index) {
    // Always reload dashboard data when switching to dashboard tab
    // Other tabs load once for performance
    if (index == 0) {
      ref.read(salesProvider.notifier).loadSales();
      ref.read(tasksProvider.notifier).loadTasks();
      ref.read(contactsProvider.notifier).loadContacts();
      ref.read(attendanceProvider.notifier).loadToday();
      ref.read(notificationsProvider.notifier).load(silent: true);
      return;
    }

    final loadedTabs = ref.read(loadedTabsProvider);
    if (!loadedTabs.contains(index)) {
      // Mark tab as loaded
      ref
          .read(loadedTabsProvider.notifier)
          .update((state) => {...state, index});

      // Load data for the selected tab
      switch (index) {
        case 1: // Sales
          ref.read(salesProvider.notifier).loadSales();
          break;
        case 2: // Expenses
          // Load expenses if needed
          break;
        case 3: // Contacts
        case 4: // More (may open contact-related screens)
          ref.read(contactsProvider.notifier).loadContacts();
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedTab = ref.watch(selectedTabProvider);

    // Load data when tab changes
    ref.listen<int>(selectedTabProvider, (previous, next) {
      _loadTabData(next);
    });

    final pages = [
      const DashboardPage(),
      const SalesListPage(),
      const ExpensesListPage(),
      const ContactsListPage(),
      const MorePage(),
    ];

    return Scaffold(
      backgroundColor: AppThemeColors.backgroundColor(context),
      body: IndexedStack(index: selectedTab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) {
          ref.read(selectedTabProvider.notifier).state = index;
          _loadTabData(index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.trending_up_outlined),
            selectedIcon: Icon(Icons.trending_up),
            label: 'Deals',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Expense',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Contacts',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_outlined),
            selectedIcon: Icon(Icons.menu),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
