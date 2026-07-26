import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/rbac_page_keys.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../../providers/sale_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/contact_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/rbac_prefetch.dart';
import '../../providers/rbac_provider.dart'
    show
        RbacLoadStatus,
        rbacProvider,
        rbacMeProvider,
        rbacAccessDigestProvider,
        rbacModuleAdminProvider,
        dashboardQuickActionSalesProvider,
        dashboardQuickActionExpensesProvider,
        dashboardTasksModuleProvider;
import '../../widgets/crm_card.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/error_widget.dart' as app_widgets;
import '../../widgets/app_section_header.dart';
import '../../widgets/dashboard_weather_banner.dart';
import '../../widgets/status_badge.dart';
import '../sales/sale_detail_page.dart';
import '../tasks/task_detail_page.dart';
import '../tasks/tasks_list_page.dart';
import '../expenses/expense_form_page.dart';
import '../attendance/widgets/today_attendance_card.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../providers/dashboard_weather_provider.dart';
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
      prefetchCrmLookupData(ref, ref.read(rbacMeProvider));
      ref.read(notificationsProvider.notifier).load(silent: true);
      // Setup periodic refresh handled by provider
    });
  }
  // Data loading is now handled by ShellPage for better performance
  // Individual tabs load their data on-demand

  Future<void> _refreshData() async {
    await ref.read(rbacProvider.notifier).load();
    final me = ref.read(rbacMeProvider);
    final futures = <Future<void>>[
      ref.read(notificationsProvider.notifier).load(silent: true),
      ref.read(dashboardWeatherProvider.notifier).refresh(),
    ];
    if (me != null) {
      futures.add(prefetchCrmLookupData(ref, me));
      if (me.hasModuleAccess(RbacPageKey.sales)) {
        futures.add(ref.read(salesProvider.notifier).loadSales());
      }
      if (me.hasModuleAccess(RbacPageKey.tasks)) {
        futures.add(ref.read(tasksProvider.notifier).loadTasks());
      }
      if (me.canNavContacts) {
        futures.add(ref.read(contactsProvider.notifier).loadContacts());
      }
      if (me.hasNav(RbacPageKey.attendance) || me.hasNav(RbacPageKey.hr)) {
        futures.add(ref.read(attendanceProvider.notifier).loadToday());
      }
    }
    await Future.wait(futures);
  }

  @override
  Widget build(BuildContext context) {
    final tasksState = ref.watch(tasksProvider);
    final themeMode = ref.watch(themeProvider);
    final isDarkMode = themeMode == ThemeMode.dark;
    final authState = ref.watch(authProvider);
    final notificationsState = ref.watch(notificationsProvider);
    final me = ref.watch(rbacMeProvider);
    ref.watch(rbacAccessDigestProvider);
    final tasksModuleAdmin = ref.watch(
      rbacModuleAdminProvider(RbacPageKey.tasks),
    );
    final canSales = ref.watch(dashboardQuickActionSalesProvider);
    final canTasks = ref.watch(dashboardTasksModuleProvider);
    final canExpenses = ref.watch(dashboardQuickActionExpensesProvider);
    final salesLead = me?.isModuleAdmin(RbacPageKey.sales) ?? false;
    final canAttendance =
        me != null &&
        (me.hasNav(RbacPageKey.attendance) || me.hasNav(RbacPageKey.hr));
    final hasAnyQuickAction = canSales || canExpenses || canTasks;
    final userFilteredTasks = ref.watch(userFilteredTasksProvider);
    final greeting = _greetingForTimeOfDay();
    final dailyQuote = _dailyInspirationalQuote();

    final bgColor = AppThemeColors.backgroundColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;

    final rbacStatus = ref.watch(rbacProvider.select((s) => s.status));
    final permissionsBootstrapping =
        authState.status == AuthStatus.loading ||
        authState.status == AuthStatus.initial ||
        (authState.status == AuthStatus.authenticated &&
            me == null &&
            (rbacStatus == RbacLoadStatus.idle ||
                rbacStatus == RbacLoadStatus.loading));
    if (permissionsBootstrapping) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const SafeArea(child: DashboardSkeleton()),
      );
    }

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
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: AppThemeColors.heroSurface(context),
                    child: MediaQuery.withClampedTextScaling(
                      minScaleFactor: 0.85,
                      maxScaleFactor: 1.2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      greeting,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            color: textSecondary,
                                            fontWeight: FontWeight.w500,
                                            height: 1.2,
                                          ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        (authState.user?.name.isNotEmpty ??
                                                false)
                                            ? authState.user!.name
                                            : ' ',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.pageTitle(
                                          context,
                                        )?.copyWith(
                                          color: textPrimary,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: AppSpacing.sm,
                                      ),
                                      child: Text(
                                        '\u201C $dailyQuote \u201D',
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: textSecondary,
                                              fontStyle: FontStyle.italic,
                                              height: 1.45,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _DashboardIconButton(
                                icon: Icons.notifications_outlined,
                                badge: notificationsState.unreadCount > 0,
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const NotificationsPage(),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              _DashboardIconButton(
                                icon: isDarkMode
                                    ? Icons.light_mode_outlined
                                    : Icons.dark_mode_outlined,
                                onPressed: () {
                                  ref
                                      .read(themeProvider.notifier)
                                      .toggleTheme();
                                },
                              ),
                            ],
                          ),
                          const DashboardWeatherBanner(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (hasAnyQuickAction)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: AppThemeColors.pagePaddingHorizontal.copyWith(
                      top: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        if (canSales) ...[
                          Expanded(
                            child: _QuickActionButton(
                              icon: salesLead
                                  ? Icons.person_add_outlined
                                  : Icons.trending_up_outlined,
                              label: salesLead ? 'Add Lead' : 'Add Deal',
                              color: primary,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const SaleFormPage(),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (canExpenses || canTasks)
                            const SizedBox(width: AppSpacing.sm),
                        ],
                        if (canExpenses) ...[
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
                          if (canTasks) const SizedBox(width: AppSpacing.sm),
                        ],
                        if (canTasks)
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
                    ),
                  ),
                ),

              SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

              if (canAttendance)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: AppThemeColors.pagePaddingHorizontal,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSectionHeader(
                          title: 'Attendance',
                          subtitle: 'Check in and track your day',
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        const TodayAttendanceCardWidget(),
                      ],
                    ),
                  ),
                ),

              if (tasksModuleAdmin && canTasks) ...[
                SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

                // Recent Tasks
                SliverToBoxAdapter(
                  child: Padding(
                    padding: AppThemeColors.pagePaddingHorizontal,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSectionHeader(
                          title: 'Recent Tasks',
                          trailing: TextButton(
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
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ),
                  ),
                ),

                // Tasks List - Use filtered tasks based on user role
                if (tasksState.isLoading && userFilteredTasks.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: AppThemeColors.pagePaddingHorizontal,
                      child: Column(
                        children: [
                          ShimmerCard(height: 72),
                          SizedBox(height: AppSpacing.sm),
                          ShimmerCard(height: 72),
                          SizedBox(height: AppSpacing.sm),
                          ShimmerCard(height: 72),
                        ],
                      ),
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
                else ...[
                  if (tasksState.isRefreshing)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Center(child: InlineRefreshIndicator()),
                      ),
                    ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index >= 5) return null;
                        final task = userFilteredTasks[index];
                        return Padding(
                          padding: EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.xxs,
                            AppSpacing.md,
                            AppSpacing.xxs,
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
                                const SizedBox(width: AppSpacing.sm),
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
                                    horizontal: AppSpacing.sm,
                                    vertical: AppSpacing.xxs,
                                  ),
                                  child: StatusBadge(
                                    status: task.status,
                                    type: 'task',
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
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }
}

String _greetingForTimeOfDay() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

const _inspirationalQuotes = [
  'Small steps every day lead to big results.',
  'Your focus today shapes your success tomorrow.',
  'Progress, not perfection.',
  'Make today count.',
  'Consistency beats intensity.',
  'One task at a time, one win at a time.',
  'Show up. Do the work. Repeat.',
  'Excellence is a habit, not an act.',
  'Start where you are. Use what you have.',
  'Discipline is choosing what you want most over what you want now.',
  'The best way to predict the future is to create it.',
  'Done is better than perfect.',
  'Energy flows where focus goes.',
  'Be proud of how far you have come.',
  'Today is a fresh chance to move forward.',
  'Action is the foundation of success.',
  'Stay curious. Keep learning. Keep growing.',
  'Your effort today is an investment in tomorrow.',
  'Clear mind, clear priorities.',
  'Turn plans into progress.',
  'Every expert was once a beginner.',
  'Build momentum with one good decision at a time.',
  'Trust the process and keep going.',
  'You do not have to be extreme, just consistent.',
  'Make it simple. Make it happen.',
  'Opportunities favor the prepared.',
  'Lead with clarity and follow through.',
  'A productive day starts with a clear intention.',
  'Celebrate progress, then keep moving.',
  'Your work matters. Make it meaningful today.',
  'Stay patient and trust your journey.',
];

String _dailyInspirationalQuote([DateTime? date]) {
  final now = date ?? DateTime.now();
  final dayKey = now.year * 10000 + now.month * 100 + now.day;
  return _inspirationalQuotes[dayKey % _inspirationalQuotes.length];
}

class _DashboardIconButton extends StatelessWidget {
  const _DashboardIconButton({
    required this.icon,
    required this.onPressed,
    this.badge = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final border = AppThemeColors.borderColor(context);
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: border),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            onPressed: onPressed,
            icon: Icon(icon, color: cs.onSurfaceVariant),
            visualDensity: VisualDensity.compact,
          ),
          if (badge)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: cs.error,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
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
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        splashColor: tonal.foreground.withValues(alpha: 0.12),
        highlightColor: tonal.foreground.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: tonal.foreground, size: 22),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      color: tonal.foreground,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
