import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/theme_provider.dart';
import '../../providers/sale_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/contact_provider.dart';
import '../dashboard/dashboard_page.dart';
import '../sales/sales_list_page.dart';
import '../expenses/expenses_list_page.dart';
import '../tasks/tasks_list_page.dart';
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

class _ShellPageState extends ConsumerState<ShellPage> {
  @override
  void initState() {
    super.initState();
    // Load dashboard data immediately after login
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTabData(0);
    });
  }

  void _loadTabData(int index) {
    // Always reload dashboard data when switching to dashboard tab
    // Other tabs load once for performance
    if (index == 0) {
      ref.read(salesProvider.notifier).loadSales();
      ref.read(tasksProvider.notifier).loadTasks();
      ref.read(contactsProvider.notifier).loadContacts();
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
        case 3: // Tasks
          ref.read(tasksProvider.notifier).loadTasks();
          break;
        case 4: // More - load contacts for other pages
          ref.read(contactsProvider.notifier).loadContacts();
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedTab = ref.watch(selectedTabProvider);
    final themeMode = ref.watch(themeProvider);
    final isDarkMode = themeMode == ThemeMode.dark;

    // Load data when tab changes
    ref.listen<int>(selectedTabProvider, (previous, next) {
      _loadTabData(next);
    });

    final pages = [
      const DashboardPage(),
      const SalesListPage(),
      const ExpensesListPage(),
      const TasksListPage(),
      const MorePage(),
    ];

    final surfaceColor = AppThemeColors.surfaceColor(context);
    final textTertiary = AppThemeColors.textTertiaryColor(context);
    final primaryColor = const Color(0xFF2563EB);

    return Scaffold(
      body: IndexedStack(index: selectedTab, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(
              left: 0,
              right: 8,
              top: 8,
              bottom: 8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  context,
                  ref,
                  index: 0,
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard,
                  label: 'Dashboard',
                  selectedTab: selectedTab,
                  isDarkMode: isDarkMode,
                  primaryColor: primaryColor,
                  textTertiary: textTertiary,
                ),
                _buildNavItem(
                  context,
                  ref,
                  index: 1,
                  icon: Icons.trending_up_outlined,
                  activeIcon: Icons.trending_up,
                  label: 'Deals',
                  selectedTab: selectedTab,
                  isDarkMode: isDarkMode,
                  primaryColor: primaryColor,
                  textTertiary: textTertiary,
                ),
                _buildNavItem(
                  context,
                  ref,
                  index: 2,
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long,
                  label: 'Expense',
                  selectedTab: selectedTab,
                  isDarkMode: isDarkMode,
                  primaryColor: primaryColor,
                  textTertiary: textTertiary,
                ),
                _buildNavItem(
                  context,
                  ref,
                  index: 3,
                  icon: Icons.checklist_outlined,
                  activeIcon: Icons.checklist,
                  label: 'Tasks',
                  selectedTab: selectedTab,
                  isDarkMode: isDarkMode,
                  primaryColor: primaryColor,
                  textTertiary: textTertiary,
                ),
                _buildNavItem(
                  context,
                  ref,
                  index: 4,
                  icon: Icons.menu_outlined,
                  activeIcon: Icons.menu,
                  label: 'More',
                  selectedTab: selectedTab,
                  isDarkMode: isDarkMode,
                  primaryColor: primaryColor,
                  textTertiary: textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    WidgetRef ref, {
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int selectedTab,
    required bool isDarkMode,
    required Color primaryColor,
    required Color textTertiary,
  }) {
    final isSelected = selectedTab == index;
    return InkWell(
      onTap: () => ref.read(selectedTabProvider.notifier).state = index,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? primaryColor : textTertiary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? primaryColor : textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
