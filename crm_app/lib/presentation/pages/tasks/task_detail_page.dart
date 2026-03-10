import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../data/models/task_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/user_repository.dart';
import '../../providers/task_provider.dart';
import '../../providers/company_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/crm_card.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/searchable_dropdown.dart';
import '../companies/companies_list_page.dart';

// Provider for users
final taskUsersProvider = FutureProvider<List>((ref) async {
  final repository = ref.watch(userRepositoryProvider);
  return repository.getUsers();
});

class TaskDetailPage extends ConsumerWidget {
  final String taskId;

  const TaskDetailPage({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksState = ref.watch(tasksProvider);
    final task = tasksState.tasks.where((t) => t.id == taskId).firstOrNull;

    final bgColor = AppThemeColors.backgroundColor(context);
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final primaryColor = const Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Task Details', style: TextStyle(color: textPrimary)),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: textPrimary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TaskFormPage(task: task),
                ),
              );
            },
          ),
        ],
      ),
      body: task == null
          ? const Center(child: LoadingWidget())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
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
                        Divider(color: textSecondary.withOpacity(0.3)),
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
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildStatusButton(
                        context,
                        ref,
                        task,
                        'pending',
                        primaryColor,
                        textPrimary,
                        textSecondary,
                        surfaceColor,
                      ),
                      _buildStatusButton(
                        context,
                        ref,
                        task,
                        'in_progress',
                        primaryColor,
                        textPrimary,
                        textSecondary,
                        surfaceColor,
                      ),
                      _buildStatusButton(
                        context,
                        ref,
                        task,
                        'completed',
                        primaryColor,
                        textPrimary,
                        textSecondary,
                        surfaceColor,
                      ),
                      _buildStatusButton(
                        context,
                        ref,
                        task,
                        'cancelled',
                        primaryColor,
                        textPrimary,
                        textSecondary,
                        surfaceColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
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
    WidgetRef ref,
    Task task,
    String status,
    Color primaryColor,
    Color textPrimary,
    Color textSecondary,
    Color surfaceColor,
  ) {
    final isSelected = task.status == status;
    return ActionChip(
      label: Text(status.replaceAll('_', ' ').toUpperCase()),
      backgroundColor: isSelected ? primaryColor : surfaceColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : textPrimary,
        fontWeight: FontWeight.w500,
      ),
      side: BorderSide(
        color: isSelected ? primaryColor : textSecondary.withOpacity(0.3),
      ),
      onPressed: isSelected
          ? null
          : () async {
              await ref
                  .read(tasksProvider.notifier)
                  .changeTaskStatus(id: task.id, status: status);
            },
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
  bool _isLoading = false;
  DateTime? _selectedDueDate;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _noteController = TextEditingController(text: widget.task?.note ?? '');
    _dueDateController = TextEditingController(
      text: widget.task?.dueDatetime != null
          ? '${widget.task!.dueDatetime!.year}-${widget.task!.dueDatetime!.month.toString().padLeft(2, '0')}-${widget.task!.dueDatetime!.day.toString().padLeft(2, '0')}'
          : '',
    );
    _selectedDueDate = widget.task?.dueDatetime;
    _selectedCompanyId = widget.task?.companyId;
    _selectedAssignToUserId = widget.task?.assignToUserId;

    // Load companies and users if not loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(companiesProvider.notifier).loadCompanies();
      ref.read(taskUsersProvider);
    });
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
        _dueDateController.text =
            '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Get current user ID for assignByUserId
      final authState = ref.read(authProvider);
      final currentUserId = authState.user?.id;

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
              assignByUserId: currentUserId,
              assignToUserId: _selectedAssignToUserId,
            );
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
            );
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
    final primaryColor = const Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.task == null ? 'New Task' : 'Edit Task',
          style: TextStyle(color: textPrimary),
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
        padding: const EdgeInsets.all(20),
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
                  hintStyle: TextStyle(color: textSecondary.withOpacity(0.6)),
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
                      final result = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const CompaniesListPage(openCreateDialog: true),
                        ),
                      );
                      if (result != null && mounted) {
                        setState(() {
                          _selectedCompanyId = result;
                        });
                      }
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
                  hintStyle: TextStyle(color: textSecondary.withOpacity(0.6)),
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
                  final usersAsync = ref.watch(taskUsersProvider);
                  return usersAsync.when(
                    loading: () => DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Assign To',
                        labelStyle: TextStyle(color: textSecondary),
                        hintText: 'Loading users...',
                        hintStyle: TextStyle(
                          color: textSecondary.withOpacity(0.6),
                        ),
                      ),
                      items: const [],
                      onChanged: null,
                    ),
                    error: (_, _) => DropdownButtonFormField<String>(
                      initialValue: _selectedAssignToUserId,
                      decoration: InputDecoration(
                        labelText: 'Assign To',
                        labelStyle: TextStyle(color: textSecondary),
                        hintText: 'Select assignee',
                        hintStyle: TextStyle(
                          color: textSecondary.withOpacity(0.6),
                        ),
                      ),
                      dropdownColor: surfaceColor,
                      items: const [],
                      onChanged: (value) {
                        setState(() {
                          _selectedAssignToUserId = value;
                        });
                      },
                    ),
                    data: (users) {
                      final userList = users.cast<User>();
                      return DropdownButtonFormField<String>(
                        initialValue: _selectedAssignToUserId,
                        decoration: InputDecoration(
                          labelText: 'Assign To',
                          labelStyle: TextStyle(color: textSecondary),
                          hintText: 'Select assignee',
                          hintStyle: TextStyle(
                            color: textSecondary.withOpacity(0.6),
                          ),
                        ),
                        dropdownColor: surfaceColor,
                        items: userList.map((user) {
                          return DropdownMenuItem(
                            value: user.id,
                            child: Text(
                              user.name,
                              style: TextStyle(color: textPrimary),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedAssignToUserId = value;
                          });
                        },
                      );
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
                  hintStyle: TextStyle(color: textSecondary.withOpacity(0.6)),
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
