import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
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
  late TextEditingController _amountReturnController;
  late TextEditingController _fromLocationController;
  late TextEditingController _toLocationController;
  late TextEditingController _purposeController;

  String? _selectedCompanyId;
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
    _amountReturnController = TextEditingController();
    _fromLocationController = TextEditingController();
    _toLocationController = TextEditingController();
    _purposeController = TextEditingController();
    _selectedTripType = 'single_trip';
    _selectedStatus = 'unpaid';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(companiesProvider.notifier).loadCompanies();
      ref.read(usersProvider.notifier).loadUsers();
      ref.read(currenciesProvider.notifier).loadCurrencies();

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
        _amountReturnController.text =
            expenseAsync.amountReturn?.toString() ?? '';
        _fromLocationController.text = expenseAsync.fromLocation ?? '';
        _toLocationController.text = expenseAsync.toLocation ?? '';
        _purposeController.text = expenseAsync.purpose ?? '';
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
    _amountReturnController.dispose();
    _fromLocationController.dispose();
    _toLocationController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  Future<void> _showCreateCompanyDialog(BuildContext context) async {
    final currenciesState = ref.read(currenciesProvider);
    final authState = ref.read(authProvider);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final borderColor = AppThemeColors.borderColor(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

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
          title: Text(
            'Create Company',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: textPrimary,
            ),
          ),
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

    setState(() => _isLoading = true);

    try {
      final amount = double.tryParse(_amountController.text) ?? 0;
      final amountReturn = _amountReturnController.text.isNotEmpty
          ? double.tryParse(_amountReturnController.text)
          : null;

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
              amountReturn: amountReturn,
              fromLocation: _fromLocationController.text.isEmpty
                  ? null
                  : _fromLocationController.text,
              toLocation: _toLocationController.text.isEmpty
                  ? null
                  : _toLocationController.text,
              purpose: _purposeController.text.isEmpty
                  ? null
                  : _purposeController.text,
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
              amountReturn: amountReturn,
              fromLocation: _fromLocationController.text.isEmpty
                  ? null
                  : _fromLocationController.text,
              toLocation: _toLocationController.text.isEmpty
                  ? null
                  : _toLocationController.text,
              purpose: _purposeController.text.isEmpty
                  ? null
                  : _purposeController.text,
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
                  prefixText: '\$ ',
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

              // Return Amount (only for round trip)
              if (_selectedTripType == 'round_trip')
                TextFormField(
                  controller: _amountReturnController,
                  style: TextStyle(color: textPrimary),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Return Amount',
                    labelStyle: TextStyle(color: textSecondary),
                    hintText: 'Enter return amount',
                    hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6)),
                    prefixText: '\$ ',
                    prefixStyle: TextStyle(color: textPrimary),
                  ),
                ),
              if (_selectedTripType == 'round_trip') const SizedBox(height: 16),

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

              // Purpose
              TextFormField(
                controller: _purposeController,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'Purpose',
                  labelStyle: TextStyle(color: textSecondary),
                  hintText: 'Enter purpose of expense',
                  hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6)),
                  prefixIcon: Icon(
                    Icons.description_outlined,
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
