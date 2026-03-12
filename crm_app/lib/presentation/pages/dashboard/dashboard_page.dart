import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../providers/sale_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/contact_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/crm_card.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/error_widget.dart' as app_widgets;
import '../sales/sale_detail_page.dart';
import '../contacts/contact_detail_page.dart';
import '../tasks/task_detail_page.dart';
import '../tasks/tasks_list_page.dart';
import '../sales/sale_detail_page.dart';
import '../contacts/contact_detail_page.dart';
import '../tasks/task_detail_page.dart';
import '../expenses/expense_form_page.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  // Data loading is now handled by ShellPage for better performance
  // Individual tabs load their data on-demand

  Future<void> _refreshData() async {
    await Future.wait([
      ref.read(salesProvider.notifier).loadSales(),
      ref.read(tasksProvider.notifier).loadTasks(),
      ref.read(contactsProvider.notifier).loadContacts(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final salesState = ref.watch(salesProvider);
    final tasksState = ref.watch(tasksProvider);
    final contactsState = ref.watch(contactsProvider);
    final themeMode = ref.watch(themeProvider);
    final isDarkMode = themeMode == ThemeMode.dark;
    final isAdmin = ref.watch(isAdminProvider);
    final authState = ref.watch(authProvider);

    // Use filtered data based on user role
    final userFilteredSales = ref.watch(userFilteredSalesProvider);
    final userFilteredClosed = ref.watch(userFilteredClosedProvider);
    final userFilteredTasks = ref.watch(userFilteredTasksProvider);
    final userPendingTasks = ref.watch(userFilteredPendingTasksProvider);
    final userInProgressTasks = ref.watch(userFilteredInProgressTasksProvider);
    final userPendingTasksSorted = ref.watch(userPendingTasksSortedProvider);

    final bgColor = AppThemeColors.backgroundColor(context);
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final textTertiary = AppThemeColors.textTertiaryColor(context);
    final borderColor = AppThemeColors.borderColor(context);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          child: CustomScrollView(
            slivers: [
              // App Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back!',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: textSecondary,
                                ),
                              ),
                              if (authState.user?.name.isNotEmpty ?? false)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    authState.user!.name,
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimary,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 12),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            child: GestureDetector(
                              onTap: () {
                                ref.read(themeProvider.notifier).toggleTheme();
                              },
                              child: Icon(
                                isDarkMode
                                    ? Icons.light_mode_outlined
                                    : Icons.dark_mode_outlined,
                                color: textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              if (isAdmin) ...[
                // KPI Cards
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Overview',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height:
                              (MediaQuery.of(context).size.width - 40) /
                                  2 /
                                  1.4 *
                                  2 +
                              40,
                          child: GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.4,
                            children: [
                              KPICard(
                                title: 'Total Deals',
                                value: '${salesState.sales.length}',
                                icon: Icons.trending_up,
                                iconColor: const Color(0xFF2563EB),
                              ),
                              KPICard(
                                title: 'Closed Deals',
                                value: '${salesState.closed.length}',
                                icon: Icons.check_circle_outline,
                                iconColor: const Color(0xFF10B981),
                              ),
                              KPICard(
                                title: 'Pending Tasks',
                                value:
                                    '${tasksState.pendingTasks.length + tasksState.inProgressTasks.length}',
                                icon: Icons.pending_actions,
                                iconColor: const Color(0xFFF59E0B),
                              ),
                              KPICard(
                                title: 'Contacts',
                                value: '${contactsState.contacts.length}',
                                icon: Icons.people_outline,
                                iconColor: const Color(0xFF8B5CF6),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],

              // Pending Tasks for non-admin
              if (!isAdmin) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Pending Tasks',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const TasksListPage(),
                                  ),
                                );
                              },
                              child: const Text('View All'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                if (userPendingTasksSorted.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: SizedBox(height: 100), // Empty space
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index >= 3) return null;
                        final task = userPendingTasksSorted[index];
                        final dueStr = task.dueDatetime != null
                            ? 'Due: ${task.dueDatetime!.day}/${task.dueDatetime!.month}'
                            : 'No due date';
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 6,
                          ),
                          child: CRMCard(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      TaskDetailPage(taskId: task.id),
                                ),
                              );
                            },
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        task.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        task.company?.name ?? 'No company',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: textSecondary,
                                        ),
                                      ),
                                      if (task.dueDatetime != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          dueStr,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: const Color(0xFFF59E0B),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFF59E0B,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Pending',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFFF59E0B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: userPendingTasksSorted.length > 3
                          ? 3
                          : userPendingTasksSorted.length,
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],

              // Quick Actions
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (!isAdmin) ...[
                            Expanded(
                              child: _QuickActionButton(
                                icon: Icons.trending_up_outlined,
                                label: 'Add Deal',
                                color: const Color(0xFF2563EB),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const SaleFormPage(),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _QuickActionButton(
                                icon: Icons.receipt_outlined,
                                label: 'Add Expense',
                                color: const Color(0xFFF59E0B),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ExpenseFormPage(),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _QuickActionButton(
                                icon: Icons.group_add_outlined,
                                label: 'Add Contacts',
                                color: const Color(0xFF8B5CF6),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ContactFormPage(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ] else ...[
                            Expanded(
                              child: _QuickActionButton(
                                icon: Icons.person_add_outlined,
                                label: 'Add Lead',
                                color: const Color(0xFF2563EB),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const SaleFormPage(),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _QuickActionButton(
                                icon: Icons.people_outline,
                                label: 'Add Contact',
                                color: const Color(0xFF8B5CF6),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ContactFormPage(),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _QuickActionButton(
                                icon: Icons.task_alt,
                                label: 'Add Task',
                                color: const Color(0xFFF59E0B),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const TaskFormPage(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              if (isAdmin) ...[
                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // Recent Tasks
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Recent Tasks',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const TasksListPage(),
                                  ),
                                );
                              },
                              child: const Text('View All'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),

                // Tasks List - Use filtered tasks based on user role
                if (tasksState.isLoading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: LoadingWidget(),
                    ),
                  )
                else if (userFilteredTasks.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: app_widgets.EmptyStateWidget(
                        title: 'No tasks yet',
                        subtitle: 'Create your first task to get started',
                        icon: Icons.task_alt,
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index >= 5) return null;
                        final task = userFilteredTasks[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 6,
                          ),
                          child: CRMCard(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      TaskDetailPage(taskId: task.id),
                                ),
                              );
                            },
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: task.status == 'completed'
                                        ? const Color(0xFF10B981)
                                        : task.status == 'in_progress'
                                        ? const Color(0xFF2563EB)
                                        : const Color(0xFFF59E0B),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        task.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        task.company?.name ?? 'No company',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: task.status == 'completed'
                                        ? const Color(
                                            0xFF10B981,
                                          ).withOpacity(0.1)
                                        : task.status == 'in_progress'
                                        ? const Color(
                                            0xFF2563EB,
                                          ).withOpacity(0.1)
                                        : const Color(
                                            0xFFF59E0B,
                                          ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    task.status.replaceAll('_', ' '),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: task.status == 'completed'
                                          ? const Color(0xFF10B981)
                                          : task.status == 'in_progress'
                                          ? const Color(0xFF2563EB)
                                          : const Color(0xFFF59E0B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: userFilteredTasks.length > 5
                          ? 5
                          : userFilteredTasks.length,
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
