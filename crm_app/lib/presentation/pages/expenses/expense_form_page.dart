import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../data/models/expense_model.dart';
import '../../providers/expense_provider.dart';
import '../../providers/company_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/currency_provider.dart';
import '../../widgets/searchable_dropdown.dart';
import '../../widgets/celebration_shell.dart';

class ExpenseFormPage extends ConsumerStatefulWidget {
  final String? expenseId;

  const ExpenseFormPage({super.key, this.expenseId});

  @override
  ConsumerState<ExpenseFormPage> createState() => _ExpenseFormPageState();
}

class _ExpenseFormPageState extends ConsumerState<ExpenseFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _fromLocationController;
  late TextEditingController _toLocationController;
  late TextEditingController _notesController;

  String? _selectedCompanyId;
  String? _selectedPurposeId;
  /// When editing an expense whose purpose id is missing from the loaded catalog.
  String? _orphanPurposeLabel;
  String? _selectedTripType;
  String? _selectedStatus;
  DateTime? _selectedDate;
  bool _isLoading = false;
  bool _celebrating = false;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _amountController = TextEditingController();
    _fromLocationController = TextEditingController();
    _toLocationController = TextEditingController();
    _notesController = TextEditingController();
    _selectedTripType = 'single_trip';
    _selectedStatus = 'unpaid';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(companiesProvider.notifier).loadCompanies();
      ref.read(usersProvider.notifier).loadUsers();
      ref.read(currenciesProvider.notifier).loadCurrencies();
      ref.read(expensePurposesProvider.future);

      // If editing, load the expense data
      if (widget.expenseId != null) {
        _loadExpense();
      }
    });
  }

  Future<void> _loadExpense() async {
    final expenseAsync = await ref.read(
      expenseDetailProvider(widget.expenseId!).future,
    );
    if (mounted) {
      setState(() {
        _amountController.text = expenseAsync.amount.toString();
        _fromLocationController.text = expenseAsync.fromLocation ?? '';
        _toLocationController.text = expenseAsync.toLocation ?? '';
        _notesController.text = expenseAsync.purpose ?? '';
        _selectedPurposeId = expenseAsync.purposeId;
        _orphanPurposeLabel = expenseAsync.purposeName?.trim().isNotEmpty == true
            ? expenseAsync.purposeName!.trim()
            : null;
        _selectedCompanyId = expenseAsync.companyId;
        _selectedTripType = expenseAsync.tripType ?? 'single_trip';
        _selectedStatus = expenseAsync.status;
        _selectedDate = expenseAsync.date;
      });
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _amountController.dispose();
    _fromLocationController.dispose();
    _toLocationController.dispose();
    _notesController.dispose();
    super.dispose();
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
          title: Text(
            'Create Company',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: textPrimary,
            ),
          ),
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

  List<ExpensePurpose> _purposesForDropdown(List<ExpensePurpose> api) {
    final active = api.where((p) => p.isActive).toList()
      ..sort((a, b) {
        final ao = a.sortOrder ?? 999;
        final bo = b.sortOrder ?? 999;
        if (ao != bo) return ao.compareTo(bo);
        return a.name.compareTo(b.name);
      });
    final pid = _selectedPurposeId;
    if (pid != null &&
        pid.isNotEmpty &&
        !active.any((p) => p.id == pid)) {
      return [
        ExpensePurpose(
          id: pid,
          name: _orphanPurposeLabel ?? 'Previous selection',
          sortOrder: -1,
          isActive: true,
        ),
        ...active,
      ];
    }
    return active;
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCompanyId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a company')));
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a date')));
      return;
    }

    if (_selectedPurposeId == null || _selectedPurposeId!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an expense purpose from the list'),
        ),
      );
      return;
    }

    final notes = _notesController.text.trim();
    final purposeNotes = notes.isEmpty ? null : notes;

    setState(() => _isLoading = true);

    try {
      final amount = double.tryParse(_amountController.text) ?? 0;

      if (widget.expenseId == null) {
        // Get current user ID
        final currentUserId = ref.read(currentUserIdProvider);

        // Create new expense
        await ref
            .read(expensesProvider.notifier)
            .createExpense(
              companyId: _selectedCompanyId!,
              date: _selectedDate!,
              amount: amount,
              amountReturn: null,
              fromLocation: _fromLocationController.text.isEmpty
                  ? null
                  : _fromLocationController.text,
              toLocation: _toLocationController.text.isEmpty
                  ? null
                  : _toLocationController.text,
              purposeId: _selectedPurposeId!.trim(),
              purpose: purposeNotes,
              tripType: _selectedTripType,
              status: _selectedStatus,
              createdByUserId: currentUserId,
            );
        if (mounted) {
          HapticFeedback.mediumImpact();
          setState(() {
            _isLoading = false;
            _celebrating = true;
          });
          _confettiController.play();
          await Future.delayed(const Duration(milliseconds: 2800));
          if (mounted) Navigator.pop(context);
        }
        return;
      } else {
        // Update existing expense
        await ref
            .read(expensesProvider.notifier)
            .updateExpense(
              id: widget.expenseId!,
              companyId: _selectedCompanyId,
              date: _selectedDate,
              amount: amount,
              amountReturn: null,
              fromLocation: _fromLocationController.text.isEmpty
                  ? null
                  : _fromLocationController.text,
              toLocation: _toLocationController.text.isEmpty
                  ? null
                  : _toLocationController.text,
              purposeId: _selectedPurposeId!.trim(),
              purpose: purposeNotes,
              tripType: _selectedTripType,
              status: _selectedStatus,
            );
        ref.invalidate(expenseDetailProvider(widget.expenseId!));
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
      if (mounted && !_celebrating) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final bgColor = AppThemeColors.backgroundColor(context);
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final borderColor = AppThemeColors.borderColor(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return CelebrationShell(
      celebrating: _celebrating,
      confettiController: _confettiController,
      title: 'Expense submitted!',
      message: 'Your expense was added successfully.',
      icon: Icons.receipt_long_rounded,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppThemeColors.appBarTitle(
          context,
          widget.expenseId == null ? 'New Expense' : 'Edit Expense',
          leading: IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close),
            onPressed: _celebrating ? null : () => Navigator.pop(context),
          ),
          actions: [
            TextButton(
              onPressed: (_isLoading || _celebrating) ? null : _saveExpense,
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
                    onAddNew: () => _showCreateCompanyDialog(context),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Company is required';
                      }
                      return null;
                    },
                  );
                },
              ),
              const SizedBox(height: 16),

              // Date Field (Required)
              TextFormField(
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'Date *',
                  labelStyle: TextStyle(color: textSecondary),
                  hintText: 'Select date',
                  hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6)),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.calendar_today, color: textSecondary),
                    onPressed: _selectDate,
                  ),
                ),
                readOnly: true,
                controller: TextEditingController(
                  text: _selectedDate != null
                      ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                      : '',
                ),
                onTap: _selectDate,
                validator: (value) {
                  if (_selectedDate == null) {
                    return 'Date is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Amount Field (Required)
              TextFormField(
                controller: _amountController,
                style: TextStyle(color: textPrimary),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount *',
                  labelStyle: TextStyle(color: textSecondary),
                  hintText: 'Enter amount',
                  hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6)),
                  prefixText: '${AppConstants.currencySymbol} ',
                  prefixStyle: TextStyle(color: textPrimary),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Amount is required';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Trip Type Dropdown
              Text(
                'Trip Type',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedTripType = 'single_trip';
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _selectedTripType == 'single_trip'
                                ? primaryColor
                                : Colors.transparent,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(11),
                              bottomLeft: Radius.circular(11),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Single Trip',
                              style: TextStyle(
                                color: _selectedTripType == 'single_trip'
                                    ? Colors.white
                                    : textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedTripType = 'round_trip';
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _selectedTripType == 'round_trip'
                                ? primaryColor
                                : Colors.transparent,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(11),
                              bottomRight: Radius.circular(11),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Round Trip',
                              style: TextStyle(
                                color: _selectedTripType == 'round_trip'
                                    ? Colors.white
                                    : textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // From Location
              TextFormField(
                controller: _fromLocationController,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'From Location',
                  labelStyle: TextStyle(color: textSecondary),
                  hintText: 'Enter starting location',
                  hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6)),
                  prefixIcon: Icon(
                    Icons.location_on_outlined,
                    color: textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // To Location
              TextFormField(
                controller: _toLocationController,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'To Location',
                  labelStyle: TextStyle(color: textSecondary),
                  hintText: 'Enter destination',
                  hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6)),
                  prefixIcon: Icon(Icons.location_on, color: textSecondary),
                ),
              ),
              const SizedBox(height: 16),

              // Purpose (catalog) + optional notes — API: purposeId + purpose
              Consumer(
                builder: (context, ref, _) {
                  final asyncPurposes = ref.watch(expensePurposesProvider);
                  return asyncPurposes.when(
                    data: (purposes) {
                      final items = _purposesForDropdown(purposes);
                      if (items.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            'No expense purposes are available. Add them via the API or ask an admin.',
                            style: TextStyle(color: textSecondary, fontSize: 14),
                          ),
                        );
                      }
                      return SearchableDropdown<String>(
                        items: items.map((p) => p.id).toList(),
                        value: _selectedPurposeId,
                        hintText: 'Select expense purpose',
                        labelText: 'Purpose *',
                        itemLabelBuilder: (id) {
                          final p = items.firstWhere((e) => e.id == id);
                          return p.name;
                        },
                        dropdownColor: surfaceColor,
                        textColor: textPrimary,
                        hintColor: textSecondary,
                        required: true,
                        onChanged: (value) {
                          setState(() {
                            _selectedPurposeId = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Select a purpose';
                          }
                          return null;
                        },
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: LinearProgressIndicator(),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Could not load expense purposes. Pull to retry or reopen.',
                        style: TextStyle(color: textSecondary, fontSize: 14),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _notesController,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  labelStyle: TextStyle(color: textSecondary),
                  hintText: 'e.g. transport, client name',
                  hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6)),
                  prefixIcon: Icon(
                    Icons.notes_outlined,
                    color: textSecondary,
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Status Dropdown (only for editing and admin users)
              if (widget.expenseId != null && isAdmin) ...[
                Text(
                  'Status',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: borderColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedStatus = 'unpaid';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _selectedStatus == 'unpaid'
                                  ? AppThemeColors.expenseUnpaidColor(context)
                                  : Colors.transparent,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(11),
                                bottomLeft: Radius.circular(11),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Unpaid',
                                style: TextStyle(
                                  color: _selectedStatus == 'unpaid'
                                      ? Colors.white
                                      : textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedStatus = 'paid';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _selectedStatus == 'paid'
                                  ? AppThemeColors.expensePaidColor(context)
                                  : Colors.transparent,
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(11),
                                bottomRight: Radius.circular(11),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Paid',
                                style: TextStyle(
                                  color: _selectedStatus == 'paid'
                                      ? Colors.white
                                      : textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
