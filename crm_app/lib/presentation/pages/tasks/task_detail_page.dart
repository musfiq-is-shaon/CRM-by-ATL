import 'package:confetti/confetti.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../data/models/task_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/user_repository.dart';
import '../../providers/task_provider.dart';
import '../../providers/company_provider.dart';
import '../../../core/constants/rbac_page_keys.dart';
import '../../providers/auth_provider.dart';
import '../../providers/rbac_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/currency_provider.dart';
import '../../widgets/crm_card.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/searchable_dropdown.dart';
import '../../widgets/celebration_shell.dart';

// Provider for users
final taskUsersProvider = FutureProvider<List>((ref) async {
  final repository = ref.watch(userRepositoryProvider);
  return repository.getUsers();
});

class TaskDetailPage extends ConsumerStatefulWidget {
  final String taskId;

  const TaskDetailPage({super.key, required this.taskId});

  @override
  ConsumerState<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends ConsumerState<TaskDetailPage> {
  late ConfettiController _confettiController;
  bool _celebrating = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(usersProvider.notifier).loadUsers();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasksState = ref.watch(tasksProvider);
    final task =
        tasksState.tasks.where((t) => t.id == widget.taskId).firstOrNull;
    final isAdmin = ref.watch(rbacModuleAdminProvider(RbacPageKey.tasks));

    final bgColor = AppThemeColors.backgroundColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return CelebrationShell(
      celebrating: _celebrating,
      confettiController: _confettiController,
      title: 'Task complete!',
      message: 'Nice work — this task is done.',
      icon: Icons.task_alt_rounded,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppThemeColors.appBarTitle(
          context,
          'Task Details',
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: _celebrating ? null : () => Navigator.pop(context),
          ),
          actions: [
            if (isAdmin)
              IconButton(
                tooltip: 'Edit task',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TaskFormPage(task: task),
                    ),
                  );
                },
              ),
            if (isAdmin)
              IconButton(
                tooltip: 'Delete task',
                icon: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                onPressed: task != null
                    ? () => _showDeleteConfirmation(context, task)
                    : null,
              ),
          ],
        ),
      body: task == null
          ? const Center(child: LoadingWidget())
          : SingleChildScrollView(
              padding: AppThemeColors.pagePaddingAll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Task Info Card
                  CRMCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                task.title,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                            StatusBadge(status: task.status, type: 'task'),
                          ],
                        ),
                        if (task.note != null && task.note!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            task.note!,
                            style: TextStyle(color: textSecondary, height: 1.5),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Divider(color: textSecondary.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        _buildInfoRow(
                          'Company',
                          task.company?.name ?? 'N/A',
                          textPrimary,
                          textSecondary,
                        ),
                        _buildInfoRow(
                          'Due Date',
                          task.dueDatetime != null
                              ? '${task.dueDatetime!.year}-${task.dueDatetime!.month.toString().padLeft(2, '0')}-${task.dueDatetime!.day.toString().padLeft(2, '0')}'
                              : 'N/A',
                          textPrimary,
                          textSecondary,
                        ),
                        _buildInfoRow(
                          'Assigned To',
                          task.assignToUser?.name ?? 'N/A',
                          textPrimary,
                          textSecondary,
                        ),
                        _buildInfoRow(
                          'Assigned By',
                          task.assignByUser?.name ?? 'N/A',
                          textPrimary,
                          textSecondary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Status Actions
                  Text(
                    'Change Status',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (task.status == 'completed' && !isAdmin) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Only an admin can change status after a task is completed.',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildStatusButton(
                        context,
                        task,
                        'pending',
                        primaryColor,
                        textPrimary,
                        isAdmin,
                      ),
                      _buildStatusButton(
                        context,
                        task,
                        'in_progress',
                        primaryColor,
                        textPrimary,
                        isAdmin,
                      ),
                      _buildStatusButton(
                        context,
                        task,
                        'completed',
                        primaryColor,
                        textPrimary,
                        isAdmin,
                      ),
                      _buildStatusButton(
                        context,
                        task,
                        'cancelled',
                        primaryColor,
                        textPrimary,
                        isAdmin,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildActivityLogSection(
                    context,
                    task,
                    textPrimary,
                    textSecondary,
                    primaryColor,
                  ),
                ],
              ),
            ),
    ),
    );
  }

  Widget _buildActivityLogSection(
    BuildContext context,
    Task task,
    Color textPrimary,
    Color textSecondary,
    Color primaryColor,
  ) {
    final logsAsync = ref.watch(taskLogsProvider(task.id));
    final usersState = ref.watch(usersProvider);
    final nameById = {
      for (final u in usersState.users)
        if (u.id.trim().isNotEmpty) u.id: u.name,
    };
    final surface = AppThemeColors.surfaceColor(context);
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activity log',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: textPrimary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        logsAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: primaryColor,
                ),
              ),
            ),
          ),
          error: (e, _) => CRMCard(
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Could not load activity log.',
                    style: TextStyle(color: textSecondary, fontSize: 14),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(taskLogsProvider(task.id)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (logs) {
            if (logs.isEmpty) {
              return Text(
                'No activity recorded yet.',
                style: TextStyle(color: textSecondary, fontSize: 14, height: 1.4),
              );
            }
            return _buildActivityTimeline(
              context,
              logs: logs,
              taskStatus: task.status,
              nameById: nameById,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              primaryColor: primaryColor,
              surface: surface,
              outlineVariant: cs.outlineVariant,
            );
          },
        ),
      ],
    );
  }

  static final _activityWhenFormat = DateFormat('MMM d, yyyy, h:mm a', 'en_US');

  TaskLog? _oldestActivityLog(List<TaskLog> logs) {
    TaskLog? best;
    DateTime? bestTime;
    for (final l in logs) {
      final t = l.createdAt ?? l.updatedAt;
      if (t == null) continue;
      if (bestTime == null || t.isBefore(bestTime)) {
        bestTime = t;
        best = l;
      }
    }
    return best;
  }

  /// When [logs] are newest-first, each entry's `status` is the task state **after** that event.
  /// Walk oldest → newest so we know the state immediately **before** each row (handles
  /// duplicate snapshot statuses on consecutive API rows).
  List<String?> _taskStatusBeforeEachLog(List<TaskLog> logs) {
    final n = logs.length;
    final prev = List<String?>.filled(n, null);
    String? stateAfterOlder;
    for (var i = n - 1; i >= 0; i--) {
      prev[i] = stateAfterOlder;
      final s = logs[i].status?.trim();
      if (s != null && s.isNotEmpty) {
        stateAfterOlder = s;
      }
    }
    return prev;
  }

  Widget _buildActivityTimeline(
    BuildContext context, {
    required List<TaskLog> logs,
    required String taskStatus,
    required Map<String, String> nameById,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryColor,
    required Color surface,
    required Color outlineVariant,
  }) {
    final creationRef = _oldestActivityLog(logs) ?? logs.last;
    final creationId = creationRef.id;
    final statusBefore = _taskStatusBeforeEachLog(logs);
    final lineColor = outlineVariant.withValues(alpha: 0.55);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 10,
          top: 14,
          bottom: 14,
          child: IgnorePointer(
            child: Container(width: 2, color: lineColor),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(logs.length, (index) {
              final log = logs[index];
              final isLast = index == logs.length - 1;
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 22),
                child: _buildActivityTimelineRow(
                  context,
                  log: log,
                  index: index,
                  logs: logs,
                  creationId: creationId,
                  statusBeforeThisLog: statusBefore[index],
                  taskStatus: taskStatus,
                  nameById: nameById,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  primaryColor: primaryColor,
                  surface: surface,
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityTimelineRow(
    BuildContext context, {
    required TaskLog log,
    required int index,
    required List<TaskLog> logs,
    required String creationId,
    required String? statusBeforeThisLog,
    required String taskStatus,
    required Map<String, String> nameById,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryColor,
    required Color surface,
  }) {
    var rawNext = log.status?.trim();
    if ((rawNext == null || rawNext.isEmpty) &&
        index == 0 &&
        (log.previousStatus?.trim().isNotEmpty ?? false)) {
      final ts = taskStatus.trim();
      if (ts.isNotEmpty) rawNext = ts;
    }
    final hasStatus = rawNext != null && rawNext.isNotEmpty;
    final nextNorm = rawNext;

    final fromApi = log.previousStatus?.trim();
    final fromChain = statusBeforeThisLog?.trim();
    // Prefer API "previous" only when it actually differs from the new status; some backends
    // echo the same value in both fields, which would hide the timeline arrow.
    String? fromNorm = fromChain;
    if (fromApi != null &&
        fromApi.isNotEmpty &&
        (nextNorm == null ||
            fromApi.toLowerCase() != nextNorm.toLowerCase())) {
      fromNorm = fromApi;
    }
    // When chain/API omit "before", infer from the next-older log row (list is newest-first).
    if ((fromNorm == null || fromNorm.isEmpty) &&
        index + 1 < logs.length) {
      final olderStatus = logs[index + 1].status?.trim();
      if (olderStatus != null && olderStatus.isNotEmpty) {
        fromNorm = olderStatus;
      }
    }

    final isCreation = creationId.isNotEmpty && log.id == creationId ||
        (creationId.isEmpty && index == logs.length - 1);
    final hasTransition = !isCreation &&
        hasStatus &&
        fromNorm != null &&
        fromNorm.isNotEmpty &&
        nextNorm != null &&
        fromNorm.toLowerCase() != nextNorm.toLowerCase();

    final who = _resolveTaskLogActorName(log, nameById);

    final when = log.createdAt ?? log.updatedAt;
    final whenText = when != null
        ? _activityWhenFormat.format(when.toLocal())
        : '—';

    final chipBg = Theme.of(context).colorScheme.surfaceContainerHighest;
    final chipFg = Theme.of(context).colorScheme.onSurfaceVariant;
    final actionLabel = isCreation
        ? 'Created'
        : (hasTransition || hasStatus
            ? 'Status changed'
            : ((log.note?.trim().isNotEmpty ?? false) ? 'Note' : 'Status changed'));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: surface, width: 2),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                who,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.22),
                  ),
                ),
                child: Text(
                  actionLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: chipFg,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      whenText,
                      style: TextStyle(
                        fontSize: 13,
                        color: textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
              if (hasTransition) ...[
                const SizedBox(height: 8),
                _taskStatusArrowLine(fromNorm, nextNorm, textSecondary),
              ] else if (!isCreation &&
                  hasStatus &&
                  nextNorm != null &&
                  nextNorm.isNotEmpty &&
                  (fromNorm == null || fromNorm.isEmpty)) ...[
                const SizedBox(height: 8),
                Text(
                  'Status: ${taskStatusLogLabel(nextNorm)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
              if (log.note != null && log.note!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  log.note!.trim(),
                  style: TextStyle(
                    fontSize: 13,
                    color: textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Single muted line `Pending → Completed` (Unicode arrow U+2192).
  Widget _taskStatusArrowLine(String from, String to, Color muted) {
    final f = taskStatusLogLabel(from.trim());
    final t = taskStatusLogLabel(to.trim());
    return Text.rich(
      TextSpan(
        style: TextStyle(
          color: muted,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 1.4,
        ),
        children: [
          TextSpan(text: f),
          TextSpan(
            text: ' \u2192 ',
            style: TextStyle(
              color: muted,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          TextSpan(text: t),
        ],
      ),
    );
  }

  String _resolveTaskLogActorName(TaskLog log, Map<String, String> nameById) {
    final fromEmbed = log.actorUser?.name.trim();
    if (fromEmbed != null && fromEmbed.isNotEmpty) return fromEmbed;

    final id = log.actorUserId?.trim();
    if (id != null && id.isNotEmpty) {
      final fromMap = nameById[id]?.trim();
      if (fromMap != null && fromMap.isNotEmpty) return fromMap;
    }
    return 'Unknown user';
  }

  Widget _buildInfoRow(
    String label,
    String value,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: textSecondary, fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              color: textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusButton(
    BuildContext context,
    Task task,
    String status,
    Color primaryColor,
    Color textPrimary,
    bool isAdmin,
  ) {
    final isSelected = task.status == status;
    final cs = Theme.of(context).colorScheme;
    final completedLocked = task.status == 'completed' && !isAdmin;
    final isOtherWhileCompleted = completedLocked && status != 'completed';

    return Opacity(
      opacity: isOtherWhileCompleted ? 0.45 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : cs.outlineVariant.withValues(alpha: 0.55),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: isSelected
                ? null
                : () async {
                    if (isOtherWhileCompleted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Only an admin can change the status of a completed task.',
                          ),
                        ),
                      );
                      return;
                    }
                    await ref.read(tasksProvider.notifier).changeTaskStatus(
                          id: task.id,
                          status: status,
                          isAdmin: isAdmin,
                          actorUserId: ref.read(currentUserIdProvider),
                        );
                    ref.invalidate(taskLogsProvider(task.id));

                    if (!context.mounted) return;
                    if (status == 'completed') {
                      HapticFeedback.mediumImpact();
                      setState(() => _celebrating = true);
                      _confettiController.play();
                      await Future.delayed(const Duration(milliseconds: 2800));
                      if (mounted) setState(() => _celebrating = false);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Status updated to ${status.replaceAll('_', ' ').toUpperCase()}',
                          ),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                status.replaceAll('_', ' ').toUpperCase(),
                style: TextStyle(
                  color: isSelected ? cs.onPrimary : textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ),
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
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to list
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

class TaskFormPage extends ConsumerStatefulWidget {
  final Task? task;

  const TaskFormPage({super.key, this.task});

  @override
  ConsumerState<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends ConsumerState<TaskFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _noteController;
  late TextEditingController _dueDateController;
  String? _selectedCompanyId;
  String? _selectedAssignToUserId;
  String? _selectedAssignByUserId;
  bool _isLoading = false;
  DateTime? _selectedDueDate;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _noteController = TextEditingController(text: widget.task?.note ?? '');
    _dueDateController = TextEditingController(
      text: widget.task?.dueDatetime != null
          ? _formatDateTime(widget.task!.dueDatetime!)
          : '',
    );
    _selectedDueDate = widget.task?.dueDatetime;
    _selectedCompanyId = widget.task?.companyId;
    _selectedAssignToUserId = widget.task?.assignToUserId;
    _selectedAssignByUserId = widget.task?.assignByUserId;

    // Load companies and users if not loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(companiesProvider.notifier).loadCompanies();
      ref.read(usersProvider.notifier).loadUsers();
      ref.read(currenciesProvider.notifier).loadCurrencies();

      // For new tasks, set the current user as default "Assigned By"
      if (widget.task == null && !_initialized) {
        _initialized = true;
        final authState = ref.read(authProvider);
        if (authState.user != null) {
          setState(() {
            _selectedAssignByUserId = authState.user!.id;
          });
        }
      }
    });
  }

  String _formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour > 12
        ? dateTime.hour - 12
        : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final amPm = dateTime.hour >= 12 ? 'PM' : 'AM';
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} $hour:$minute $amPm';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      if (!mounted) return;
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDueDate ?? DateTime.now()),
      );

      setState(() {
        final dateTime = pickedTime != null
            ? DateTime(
                picked.year,
                picked.month,
                picked.day,
                pickedTime.hour,
                pickedTime.minute,
              )
            : DateTime(picked.year, picked.month, picked.day);
        _selectedDueDate = dateTime;
        _dueDateController.text = _formatDateTime(dateTime);
      });
    }
  }

  Future<void> _showCreateCompanyDialog(BuildContext context) async {
    final usersState = ref.read(usersProvider);
    final currenciesState = ref.read(currenciesProvider);
    final authState = ref.read(authProvider);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final borderColor = AppThemeColors.borderColor(context);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final surfaceColor = AppThemeColors.surfaceColor(context);

    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final countryController = TextEditingController();

    String? selectedKamUserId = authState.user?.id;
    if (selectedKamUserId != null &&
        !usersState.users.any((u) => u.id == selectedKamUserId)) {
      selectedKamUserId =
          usersState.users.isNotEmpty ? usersState.users.first.id : null;
    }
    if (selectedKamUserId == null && usersState.users.isNotEmpty) {
      selectedKamUserId = usersState.users.first.id;
    }

    // Set default currency if available
    String? selectedCurrencyId;
    if (currenciesState.currencies.isNotEmpty) {
      selectedCurrencyId = currenciesState.currencies.first.id;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: Text('Create Company', style: TextStyle(color: textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                TextField(
                  controller: nameController,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Company Name *',
                    labelStyle: TextStyle(color: textSecondary),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Currency Dropdown
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedCurrencyId,
                  decoration: InputDecoration(
                    labelText: 'Currency *',
                    labelStyle: TextStyle(color: textSecondary),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                  items: currenciesState.currencies.map((currency) {
                    return DropdownMenuItem(
                      value: currency.id,
                      child: Text('${currency.code} - ${currency.name}'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedCurrencyId = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: locationController,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Location',
                    labelStyle: TextStyle(color: textSecondary),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: countryController,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Country',
                    labelStyle: TextStyle(color: textSecondary),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: ValueKey(selectedKamUserId ?? 'kam'),
                  initialValue: selectedKamUserId,
                  decoration: InputDecoration(
                    labelText: 'KAM (Key Account Manager) *',
                    labelStyle: TextStyle(color: textSecondary),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                  dropdownColor: surfaceColor,
                  items: usersState.users
                      .map(
                        (user) => DropdownMenuItem(
                          value: user.id,
                          child: Text(user.name),
                        ),
                      )
                      .toList(),
                  onChanged: usersState.users.isEmpty
                      ? null
                      : (value) {
                          setDialogState(() => selectedKamUserId = value);
                        },
                ),
              ],
            ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: primaryColor)),
            ),
            TextButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty &&
                    selectedCurrencyId != null &&
                    selectedKamUserId != null &&
                    selectedKamUserId!.isNotEmpty) {
                  await ref
                      .read(companiesProvider.notifier)
                      .createCompany(
                        name: nameController.text,
                        location: locationController.text.isNotEmpty
                            ? locationController.text
                            : null,
                        country: countryController.text.isNotEmpty
                            ? countryController.text
                            : null,
                        kamUserId: selectedKamUserId!,
                        currencyId: selectedCurrencyId!,
                        createdByUserId: authState.user?.id,
                      );
                  // Get the newly created company (first in the list)
                  final companies = ref.read(companiesProvider).companies;
                  if (companies.isNotEmpty && context.mounted) {
                    Navigator.pop(context, companies.first.id);
                  } else if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
              child: Text('Create', style: TextStyle(color: primaryColor)),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedCompanyId = result;
      });
    }
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Get current user ID for assignByUserId if not manually selected
      final authState = ref.read(authProvider);
      final currentUserId = authState.user?.id;

      if (kDebugMode) {
        debugPrint('=== AUTH DEBUG ===');
        debugPrint('authState.user: ${authState.user}');
        debugPrint('authState.user?.id: $currentUserId');
        debugPrint('authState.user?.name: ${authState.user?.name}');
        debugPrint('==================');
      }

      // Use selected Assign By user, or fall back to current user
      final assignByUserId = _selectedAssignByUserId ?? currentUserId;

      if (widget.task == null) {
        // Create new task - need companyId and dueDatetime
        if (_selectedCompanyId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a company')),
          );
          setState(() => _isLoading = false);
          return;
        }

        if (_selectedDueDate == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a due date')),
          );
          setState(() => _isLoading = false);
          return;
        }

        await ref
            .read(tasksProvider.notifier)
            .createTask(
              title: _titleController.text,
              companyId: _selectedCompanyId!,
              dueDatetime: _selectedDueDate!,
              note: _noteController.text.isEmpty ? null : _noteController.text,
              assignByUserId: assignByUserId,
              assignToUserId: _selectedAssignToUserId,
              actorUserId: currentUserId,
            );

        if (kDebugMode) {
          debugPrint('=== TASK CREATE DEBUG ===');
          debugPrint('Title: ${_titleController.text}');
          debugPrint('CompanyId: $_selectedCompanyId');
          debugPrint('DueDatetime: $_selectedDueDate');
          debugPrint('Note: ${_noteController.text}');
          debugPrint('assignByUserId: $assignByUserId');
          debugPrint('assignToUserId: $_selectedAssignToUserId');
          debugPrint('actorUserId: $currentUserId');
          debugPrint('===========================');
        }
      } else {
        // Update existing task
        await ref
            .read(tasksProvider.notifier)
            .updateTask(
              id: widget.task!.id,
              title: _titleController.text,
              note: _noteController.text.isEmpty ? null : _noteController.text,
              dueDatetime: _selectedDueDate,
              assignToUserId: _selectedAssignToUserId,
              assignByUserId: assignByUserId,
            );
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        // Parse the error message for better user feedback
        String errorMessage = 'Error: $e';

        // Check if it's a validation error or specific error
        if (e.toString().contains('ValidationException') ||
            e.toString().contains('422')) {
          errorMessage = 'Validation error. Please check your input.';
        } else if (e.toString().contains('401')) {
          errorMessage = 'Authentication error. Please log in again.';
        } else if (e.toString().contains('403')) {
          errorMessage = 'You do not have permission to perform this action.';
        } else if (e.toString().contains('500')) {
          errorMessage = 'Server error. Please try again later.';
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = AppThemeColors.backgroundColor(context);
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppThemeColors.appBarTitle(
        context,
        widget.task == null ? 'New Task' : 'Edit Task',
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveTask,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppThemeColors.pagePaddingAll,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Field (Required)
              TextFormField(
                controller: _titleController,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'Title *',
                  labelStyle: TextStyle(color: textSecondary),
                  hintText: 'Enter task title',
                  hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Company Dropdown (Required)
              Consumer(
                builder: (context, ref, child) {
                  final companiesState = ref.watch(companiesProvider);
                  return SearchableDropdown<String>(
                    items: companiesState.companies.map((c) => c.id).toList(),
                    value: _selectedCompanyId,
                    hintText: 'Select a company',
                    labelText: 'Company *',
                    itemLabelBuilder: (id) {
                      final company = companiesState.companies
                          .where((c) => c.id == id)
                          .firstOrNull;
                      return company?.name ?? '';
                    },
                    dropdownColor: surfaceColor,
                    textColor: textPrimary,
                    hintColor: textSecondary,
                    required: true,
                    onChanged: (value) {
                      setState(() {
                        _selectedCompanyId = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Company is required';
                      }
                      return null;
                    },
                    onAddNew: () async {
                      ref.read(usersProvider.notifier).loadUsers();
                      await _showCreateCompanyDialog(context);
                    },
                  );
                },
              ),
              const SizedBox(height: 16),

              // Due Date Field (Required)
              TextFormField(
                controller: _dueDateController,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'Due Date *',
                  labelStyle: TextStyle(color: textSecondary),
                  hintText: 'Select due date',
                  hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6)),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.calendar_today, color: textSecondary),
                    onPressed: _selectDueDate,
                  ),
                ),
                readOnly: true,
                onTap: _selectDueDate,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Due date is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Assign To User Dropdown (Optional)
              Consumer(
                builder: (context, ref, child) {
                  final usersState = ref.watch(usersProvider);
                  final selectedUser = _selectedAssignToUserId != null
                      ? usersState.users
                            .where((u) => u.id == _selectedAssignToUserId)
                            .firstOrNull
                      : null;

                  return SearchableDropdown<User>(
                    items: usersState.users,
                    value: selectedUser,
                    hintText: 'Search by name or email...',
                    labelText: 'Assign To',
                    itemLabelBuilder: (user) => '${user.name} (${user.email})',
                    dropdownColor: surfaceColor,
                    textColor: textPrimary,
                    hintColor: textSecondary,
                    onChanged: (user) {
                      if (kDebugMode) {
                        debugPrint('=== DROPDOWN ONCHANGE DEBUG ===');
                        debugPrint('Selected user: ${user?.id} - ${user?.name}');
                        debugPrint('================================');
                      }
                      setState(() {
                        _selectedAssignToUserId = user?.id;
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 16),

              // Assign By User Dropdown (Optional - Admin only)
              Consumer(
                builder: (context, ref, child) {
                  final isAdmin = ref.watch(rbacModuleAdminProvider(RbacPageKey.tasks));
                  final usersState = ref.watch(usersProvider);
                  final selectedUser = _selectedAssignByUserId != null
                      ? usersState.users
                            .where((u) => u.id == _selectedAssignByUserId)
                            .firstOrNull
                      : null;

                  // Only show Assigned By dropdown for admins
                  if (!isAdmin) {
                    return const SizedBox.shrink();
                  }

                  return SearchableDropdown<User>(
                    items: usersState.users,
                    value: selectedUser,
                    hintText: 'Search by name or email...',
                    labelText: 'Assigned By',
                    itemLabelBuilder: (user) => '${user.name} (${user.email})',
                    dropdownColor: surfaceColor,
                    textColor: textPrimary,
                    hintColor: textSecondary,
                    onChanged: (user) {
                      setState(() {
                        _selectedAssignByUserId = user?.id;
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 16),

              // Note Field
              TextFormField(
                controller: _noteController,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'Note',
                  labelStyle: TextStyle(color: textSecondary),
                  hintText: 'Add notes about this task',
                  hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6)),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
