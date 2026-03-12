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
import '../../providers/currency_provider.dart';
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
    final isAdmin = ref.watch(isAdminProvider);

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
          if (isAdmin)
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
          if (isAdmin)
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red),
              onPressed: task != null
                  ? () => _showDeleteConfirmation(context, ref, task)
                  : null,
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? primaryColor
            : (isDarkMode ? surfaceColor : Colors.white),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? primaryColor : textSecondary.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: primaryColor.withOpacity(0.3),
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
                  await ref
                      .read(tasksProvider.notifier)
                      .changeTaskStatus(id: task.id, status: status);
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              status.replaceAll('_', ' ').toUpperCase(),
              style: TextStyle(
                color: isSelected ? Colors.white : textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, Task task) {
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final primaryColor = const Color(0xFF2563EB);
    final errorColor = const Color(0xFFEF4444);

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
            child: Text('Cancel', style: TextStyle(color: primaryColor)),
          ),
          TextButton(
            onPressed: () {
              ref.read(tasksProvider.notifier).deleteTask(task.id);
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to list
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Task deleted successfully'),
                  backgroundColor: primaryColor,
                ),
              );
            },
            child: Text('Delete', style: TextStyle(color: errorColor)),
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
    final primaryColor = const Color(0xFF2563EB);
    final surfaceColor = AppThemeColors.surfaceColor(context);

    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final countryController = TextEditingController();

    // Set current user as default KAM
    String? selectedKamUserId = authState.user?.id;

    // Set default currency if available
    String? selectedCurrencyId;
    if (currenciesState.currencies.isNotEmpty) {
      selectedCurrencyId = currenciesState.currencies.first.id;
    }

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
                // Currency Dropdown
                DropdownButtonFormField<String>(
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
                if (nameController.text.isNotEmpty &&
                    selectedCurrencyId != null) {
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
                        currencyId: selectedCurrencyId!,
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

      // Debug: Show auth state
      debugPrint('=== AUTH DEBUG ===');
      debugPrint('authState.user: ${authState.user}');
      debugPrint('authState.user?.id: $currentUserId');
      debugPrint('authState.user?.name: ${authState.user?.name}');
      debugPrint('==================');

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

        // Debug: Print what was sent (remove in production)
        debugPrint('=== TASK CREATE DEBUG ===');
        debugPrint('Title: ${_titleController.text}');
        debugPrint('CompanyId: $_selectedCompanyId');
        debugPrint('DueDatetime: $_selectedDueDate');
        debugPrint('Note: ${_noteController.text}');
        debugPrint('assignByUserId: $assignByUserId');
        debugPrint('assignToUserId: $_selectedAssignToUserId');
        debugPrint('actorUserId: $currentUserId');
        debugPrint('===========================');
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
                      debugPrint('=== DROPDOWN ONCHANGE DEBUG ===');
                      debugPrint('Selected user: ${user?.id} - ${user?.name}');
                      debugPrint('================================');
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
                  final isAdmin = ref.watch(isAdminProvider);
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
