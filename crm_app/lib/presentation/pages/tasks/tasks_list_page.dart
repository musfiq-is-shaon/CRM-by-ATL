import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/task_model.dart';
import '../../providers/task_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/crm_card.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/error_widget.dart' as app_widgets;
import '../../widgets/searchable_dropdown.dart';
import '../../widgets/app_search_filter_bar.dart';
import 'task_detail_page.dart';

class TasksListPage extends ConsumerStatefulWidget {
  const TasksListPage({super.key});

  @override
  ConsumerState<TasksListPage> createState() => _TasksListPageState();
}

class _TasksListPageState extends ConsumerState<TasksListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tasksProvider.notifier).loadTasks();
      ref.read(usersProvider.notifier).loadUsers();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasksState = ref.watch(tasksProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final currentUserId = ref.watch(currentUserIdProvider);
    final userFilteredTasks = ref.watch(userFilteredTasksProvider);

    final bgColor = AppThemeColors.backgroundColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppThemeColors.appBarTitle(
        context,
        'Tasks',
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: Column(
            children: [
              AppSearchFilterBar(
                controller: _searchController,
                hintText: 'Search tasks...',
                onChanged: (value) {
                  setState(() {});
                  ref.read(tasksProvider.notifier).setSearchQuery(value);
                },
                onClear: () {
                  _searchController.clear();
                  ref.read(tasksProvider.notifier).setSearchQuery(null);
                  setState(() {});
                },
                onFilterTap: isAdmin ? () => _showFilterDialog(context) : null,
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.45),
              ),
              TabBar(
                controller: _tabController,
                isScrollable: false,
                padding: EdgeInsets.zero,
                automaticIndicatorColorAdjustment: false,
                labelColor: primaryColor,
                unselectedLabelColor: textSecondary,
                indicatorColor: primaryColor,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Pending'),
                  Tab(text: 'Completed'),
                  Tab(text: 'All'),
                ],
                onTap: (index) {
                  final statuses = ['pending', 'completed', null];
                  ref
                      .read(tasksProvider.notifier)
                      .setStatusFilter(statuses[index]);
                },
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTasksList(
            tasksState,
            'pending',
            userFilteredTasks,
            isAdmin,
            currentUserId,
          ),
          _buildTasksList(
            tasksState,
            'completed',
            userFilteredTasks,
            isAdmin,
            currentUserId,
          ),
          _buildTasksList(
            tasksState,
            null,
            userFilteredTasks,
            isAdmin,
            currentUserId,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TaskFormPage()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTasksList(
    TasksState state,
    String? status,
    List<Task> userTasks,
    bool isAdmin,
    String? currentUserId,
  ) {
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final textTertiary = AppThemeColors.textTertiaryColor(context);

    if (state.isLoading) {
      return const LoadingWidget();
    }

    // Use all tasks as base - filtering will be applied locally
    var tasks = state.tasks;

    // Apply user role filtering (admin sees all, regular users see only their assigned tasks)
    if (!isAdmin && currentUserId != null) {
      tasks = tasks.where((t) => t.assignToUserId == currentUserId).toList();
    }

    // Apply search filter locally
    if (state.searchQuery != null && state.searchQuery!.isNotEmpty) {
      final query = state.searchQuery!.toLowerCase();
      tasks = tasks.where((t) {
        final taskNameMatch = t.title.toLowerCase().contains(query);
        final companyNameMatch =
            t.company?.name.toLowerCase().contains(query) ?? false;
        return taskNameMatch || companyNameMatch;
      }).toList();
    }

    // Apply assignee filter locally
    if (state.assignToUserIdFilter != null &&
        state.assignToUserIdFilter!.isNotEmpty) {
      tasks = tasks
          .where((t) => t.assignToUserId == state.assignToUserIdFilter)
          .toList();
    }

    // Apply date range filter locally
    if (state.startDate != null || state.endDate != null) {
      tasks = tasks.where((t) {
        if (t.dueDatetime == null) return false;
        final taskDate = DateTime(
          t.dueDatetime!.year,
          t.dueDatetime!.month,
          t.dueDatetime!.day,
        );
        if (state.startDate != null) {
          final start = DateTime(
            state.startDate!.year,
            state.startDate!.month,
            state.startDate!.day,
          );
          if (taskDate.isBefore(start)) return false;
        }
        if (state.endDate != null) {
          final end = DateTime(
            state.endDate!.year,
            state.endDate!.month,
            state.endDate!.day,
          );
          if (taskDate.isAfter(end)) return false;
        }
        return true;
      }).toList();
    }

    // Apply status filter locally (from tab selection)
    if (status != null) {
      tasks = tasks.where((t) => t.status == status).toList();
    }

    if (tasks.isEmpty) {
      return app_widgets.EmptyStateWidget(
        title: 'No tasks found',
        subtitle: status != null
            ? 'No $status tasks yet'
            : 'Create your first task',
        icon: Icons.task_alt,
        buttonText: 'Add Task',
        onButtonPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TaskFormPage()),
          );
        },
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(tasksProvider.notifier).loadTasks(),
      child: ListView.builder(
        padding: AppThemeColors.pagePaddingAll,
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CRMCard(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TaskDetailPage(taskId: task.id),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              task.company?.name ?? 'No company',
                              style: TextStyle(
                                fontSize: 14,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StatusBadge(status: task.status, type: 'task'),
                          const SizedBox(width: 4),
                          if (isAdmin)
                            PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert, color: textTertiary),
                              onSelected: (value) {
                                if (value == 'delete') {
                                  _showDeleteConfirmation(context, task);
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem<String>(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete_outline,
                                        color: Colors.red[700],
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Delete',
                                        style: TextStyle(
                                          color: Colors.red[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                  if (task.dueDatetime != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: _getDueDateColor(context, task.dueDatetime!),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Due: ${_formatDate(task.dueDatetime!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: _getDueDateColor(context, task.dueDatetime!),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (task.note != null && task.note!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      task.note!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: textTertiary),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getDueDateColor(BuildContext context, DateTime dueDate) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    if (dueDate.isBefore(now)) {
      return cs.error;
    } else if (dueDate.difference(now).inDays <= 1) {
      return cs.secondary;
    }
    return cs.onSurfaceVariant;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showFilterDialog(BuildContext context) {
    final tasksState = ref.read(tasksProvider);
    final usersState = ref.read(usersProvider);
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final borderColor = AppThemeColors.borderColor(context);

    String? selectedAssigneeId = tasksState.assignToUserIdFilter;
    DateTime? selectedStartDate = tasksState.startDate;
    DateTime? selectedEndDate = tasksState.endDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            top: AppSpacing.md,
            bottom: AppSpacing.md + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filters',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      ref.read(tasksProvider.notifier).clearFilters();
                      _searchController.clear();
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Clear All',
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.md),

              // Assignee Dropdown with Search
              Text(
                'Assigned To',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
              SizedBox(height: AppSpacing.xs),
              Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: SearchableDropdown<User>(
                  items: usersState.users,
                  value: selectedAssigneeId != null
                      ? usersState.users
                            .where((u) => u.id == selectedAssigneeId)
                            .firstOrNull
                      : null,
                  hintText: 'Search by name or email...',
                  labelText: '',
                  dropdownColor: surfaceColor,
                  textColor: textPrimary,
                  hintColor: textSecondary,
                  itemLabelBuilder: (user) => '${user.name} (${user.email})',
                  onChanged: (user) {
                    setModalState(() => selectedAssigneeId = user?.id);
                  },
                ),
              ),
              SizedBox(height: AppSpacing.md),

              // Date Range
              Text(
                'Due Date',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
              SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: _buildDateButton(
                      context: context,
                      label: 'Start Date',
                      date: selectedStartDate,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      borderColor: borderColor,
                      surfaceColor: surfaceColor,
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedStartDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (date != null) {
                          setModalState(() => selectedStartDate = date);
                        }
                      },
                      onClear: () =>
                          setModalState(() => selectedStartDate = null),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDateButton(
                      context: context,
                      label: 'End Date',
                      date: selectedEndDate,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      borderColor: borderColor,
                      surfaceColor: surfaceColor,
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedEndDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (date != null) {
                          setModalState(() => selectedEndDate = date);
                        }
                      },
                      onClear: () =>
                          setModalState(() => selectedEndDate = null),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.lg),

              // Apply Button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    ref
                        .read(tasksProvider.notifier)
                        .setAssigneeFilter(selectedAssigneeId);
                    ref
                        .read(tasksProvider.notifier)
                        .setDateRange(selectedStartDate, selectedEndDate);
                    Navigator.pop(context);
                  },
                  child: const Text('Apply Filters'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateButton({
    required BuildContext context,
    required String label,
    required DateTime? date,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
    required Color surfaceColor,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 18, color: textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                date != null ? '${date.day}/${date.month}/${date.year}' : label,
                style: TextStyle(
                  color: date != null ? textPrimary : textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
            if (date != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close, size: 18, color: textSecondary),
              )
            else
              Icon(Icons.arrow_drop_down, color: textSecondary),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Task task) {
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Task', style: TextStyle(color: textPrimary)),
        content: Text(
          'Are you sure you want to delete "${task.title}"? This action cannot be undone.',
          style: TextStyle(color: textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: cs.primary)),
          ),
          TextButton(
            onPressed: () {
              ref.read(tasksProvider.notifier).deleteTask(task.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Task deleted successfully'),
                  backgroundColor: cs.inverseSurface,
                ),
              );
            },
            child: Text('Delete', style: TextStyle(color: cs.error)),
          ),
        ],
      ),
    );
  }
}
