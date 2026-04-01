import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/theme/design_tokens.dart';
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
import '../expenses/expense_form_page.dart';
import '../attendance/widgets/today_attendance_card.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/notifications_provider.dart';
import '../main/notifications_page.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(attendanceProvider.notifier);
      notifier.loadToday(); // Initial load
      ref.read(notificationsProvider.notifier).load(silent: true);
      // Setup periodic refresh handled by provider
    });
  }
  // Data loading is now handled by ShellPage for better performance
  // Individual tabs load their data on-demand

  Future<void> _refreshData() async {
    await Future.wait([
      ref.read(salesProvider.notifier).loadSales(),
      ref.read(tasksProvider.notifier).loadTasks(),
      ref.read(contactsProvider.notifier).loadContacts(),
      ref.read(attendanceProvider.notifier).loadToday(),
      ref.read(notificationsProvider.notifier).load(silent: true),
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
    final notificationsState = ref.watch(notificationsProvider);

    final userFilteredTasks = ref.watch(userFilteredTasksProvider);
    final userPendingTasksSorted = ref.watch(userPendingTasksSortedProvider);

    final bgColor = AppThemeColors.backgroundColor(context);
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final borderColor = AppThemeColors.borderColor(context);
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // App Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: AppThemeColors.pagePaddingAll,
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
                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: surfaceColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const NotificationsPage(),
                                          ),
                                        );
                                      },
                                      icon: Icon(
                                        Icons.notifications_outlined,
                                        color: textSecondary,
                                      ),
                                    ),
                                    if (notificationsState.unreadCount > 0)
                                      Positioned(
                                        right: 6,
                                        top: 6,
                                        child: Container(
                                          width: 9,
                                          height: 9,
                                          decoration: BoxDecoration(
                                            color: cs.error,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: surfaceColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: borderColor),
                                ),
                                child: IconButton(
                                  onPressed: () {
                                    ref.read(themeProvider.notifier).toggleTheme();
                                  },
                                  icon: Icon(
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
                    ],
                  ),
                ),
              ),
              if (isAdmin) ...[
                // KPI Cards
                SliverToBoxAdapter(
                  child: Padding(
                    padding: AppThemeColors.pagePaddingHorizontal,
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
                              (MediaQuery.of(context).size.width - 32) /
                                  2 /
                                  1.4 *
                                  2 +
                              32,
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
                                iconColor: primary,
                              ),
                              KPICard(
                                title: 'Closed Deals',
                                value: '${salesState.closed.length}',
                                icon: Icons.check_circle_outline,
                                iconColor: cs.tertiary,
                              ),
                              KPICard(
                                title: 'Pending Tasks',
                                value:
                                    '${tasksState.pendingTasks.length + tasksState.inProgressTasks.length}',
                                icon: Icons.pending_actions,
                                iconColor: cs.secondary,
                              ),
                              KPICard(
                                title: 'Contacts',
                                value: '${contactsState.contacts.length}',
                                icon: Icons.people_outline,
                                iconColor: cs.tertiary,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
              ],

              // Quick Actions
              SliverToBoxAdapter(
                child: Padding(
                  padding: AppThemeColors.pagePaddingHorizontal,
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
                      if (!isAdmin)
                        Row(
                          children: [
                            Expanded(
                              child: _QuickActionButton(
                                icon: Icons.trending_up_outlined,
                                label: 'Add Deal',
                                color: primary,
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
                                color: cs.secondary,
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
                                icon: Icons.checklist_outlined,
                                label: 'Tasks',
                                color: cs.tertiary,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const TasksListPage(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _QuickActionButton(
                                    icon: Icons.person_add_outlined,
                                    label: 'Add Lead',
                                    color: primary,
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
                                    color: cs.tertiary,
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
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _QuickActionButton(
                                    icon: Icons.task_alt,
                                    label: 'Add Task',
                                    color: cs.secondary,
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
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _QuickActionButton(
                                    icon: Icons.checklist_outlined,
                                    label: 'Tasks',
                                    color: primary,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const TasksListPage(),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

              SliverToBoxAdapter(
                child: Padding(
                  padding: AppThemeColors.pagePaddingHorizontalBottomXs,
                  child: const TodayAttendanceCardWidget(),
                ),
              ),

              // Pending Tasks for non-admin (after Quick Actions + attendance)
              if (!isAdmin) ...[
                SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: AppThemeColors.pagePaddingHorizontal,
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
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: AppThemeColors.pagePaddingHorizontalBottomTight,
                      child: Text(
                        'No pending tasks',
                        style: TextStyle(
                          fontSize: 14,
                          color: textSecondary,
                        ),
                      ),
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
                        final accent = cs.secondary;
                        final chipBg = accent.withValues(alpha: 0.12);
                        return Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
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
                                    color: accent,
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
                                            color: accent,
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
                                    color: chipBg,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Pending',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: accent,
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
              ],

              if (isAdmin) ...[
                SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

                // Recent Tasks
                SliverToBoxAdapter(
                  child: Padding(
                    padding: AppThemeColors.pagePaddingHorizontal,
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
                      padding: AppThemeColors.pagePaddingAll,
                      child: LoadingWidget(),
                    ),
                  )
                else if (userFilteredTasks.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: AppThemeColors.pagePaddingAll,
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
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
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
                                        ? cs.tertiary
                                        : task.status == 'in_progress'
                                        ? primary
                                        : cs.secondary,
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
                                        ? cs.tertiary.withValues(alpha: 0.12)
                                        : task.status == 'in_progress'
                                        ? primary.withValues(alpha: 0.12)
                                        : cs.secondary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    task.status.replaceAll('_', ' '),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: task.status == 'completed'
                                          ? cs.tertiary
                                          : task.status == 'in_progress'
                                          ? primary
                                          : cs.secondary,
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
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
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
    final tonal = AppThemeColors.tonalForAccent(context, color);
    return Material(
      color: tonal.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: tonal.foreground.withValues(alpha: 0.12),
        highlightColor: tonal.foreground.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: tonal.foreground, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: tonal.foreground,
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
