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
  String? _selectedAssignByUserId;
  bool _isLoading = false;
  DateTime? _selectedDueDate;

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
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final borderColor = AppThemeColors.borderColor(context);
    final primaryColor = const Color(0xFF2563EB);
    final surfaceColor = AppThemeColors.surfaceColor(context);

    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final countryController = TextEditingController();
    String? selectedKamUserId;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Create Company', style: TextStyle(color: textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                  value: selectedKamUserId,
                  decoration: InputDecoration(
                    labelText: 'KAM (Key Account Manager)',
                    labelStyle: TextStyle(color: textSecondary),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                  dropdownColor: surfaceColor,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Select KAM'),
                    ),
                    ...usersState.users.map(
                      (user) => DropdownMenuItem(
                        value: user.id,
                        child: Text(
                          user.name,
                          style: TextStyle(color: textPrimary),
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setDialogState(() => selectedKamUserId = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: primaryColor)),
            ),
            TextButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
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
                        kamUserId: selectedKamUserId ?? '',
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
              assignByUserId: assignByUserId,
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
                      setState(() {
                        _selectedAssignToUserId = user?.id;
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 16),

              // Assign By User Dropdown (Optional)
              Consumer(
                builder: (context, ref, child) {
                  final usersState = ref.watch(usersProvider);
                  final selectedUser = _selectedAssignByUserId != null
                      ? usersState.users
                            .where((u) => u.id == _selectedAssignByUserId)
                            .firstOrNull
                      : null;

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
