import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../data/models/sale_model.dart';
import '../../providers/sale_provider.dart';
import '../../providers/company_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/currency_provider.dart';
import '../../../data/repositories/sale_repository.dart';
import '../../widgets/crm_card.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/searchable_dropdown.dart';
import '../../widgets/celebration_shell.dart';

class SaleDetailPage extends ConsumerStatefulWidget {
  final String saleId;

  const SaleDetailPage({super.key, required this.saleId});

  @override
  ConsumerState<SaleDetailPage> createState() => _SaleDetailPageState();
}

class _SaleDetailPageState extends ConsumerState<SaleDetailPage> {
  late ConfettiController _confettiController;
  bool _celebrating = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saleAsync = ref.watch(saleDetailProvider(widget.saleId));

    final bgColor = AppThemeColors.backgroundColor(context);
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return saleAsync.when(
      loading: () => Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: surfaceColor,
          title: Text('Deal Details', style: TextStyle(color: textPrimary)),
        ),
        body: const Center(child: LoadingWidget()),
      ),
      error: (error, stack) => Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: surfaceColor,
          title: Text('Deal Details', style: TextStyle(color: textPrimary)),
        ),
        body: Center(
          child: Text('Error: $error', style: TextStyle(color: textPrimary)),
        ),
      ),
      data: (sale) => CelebrationShell(
        celebrating: _celebrating,
        confettiController: _confettiController,
        title: 'You won!',
        message: 'This deal is marked Closed Won.',
        icon: Icons.emoji_events_rounded,
        child: _buildContent(
          context,
          sale,
          bgColor,
          surfaceColor,
          textPrimary,
          textSecondary,
          primaryColor,
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    Sale sale,
    Color bgColor,
    Color surfaceColor,
    Color textPrimary,
    Color textSecondary,
    Color primaryColor,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Deal Details', style: TextStyle(color: textPrimary)),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: textPrimary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SaleFormPage(sale: sale),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: cs.error),
            onPressed: () => _showDeleteDialog(context, sale),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Deal Info Card
            CRMCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          sale.prospect,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                      ),
                      StatusBadge(status: sale.status, type: 'sale'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    'Company',
                    sale.company?.name ?? 'N/A',
                    textPrimary,
                    textSecondary,
                  ),
                  if (sale.company?.kamUser != null)
                    _buildInfoRow(
                      'KAM',
                      sale.company!.kamUser!.name,
                      textPrimary,
                      textSecondary,
                    ),
                  _buildInfoRow(
                    'Category',
                    sale.category?.toUpperCase() ?? 'N/A',
                    textPrimary,
                    textSecondary,
                  ),
                  _buildInfoRow(
                    'Expected Revenue',
                    '\$${sale.expectedRevenue?.toStringAsFixed(2) ?? '0'}',
                    textPrimary,
                    textSecondary,
                  ),
                  _buildInfoRow(
                    'Expected Closing',
                    sale.expectedClosingDate != null
                        ? '${sale.expectedClosingDate!.year}-${sale.expectedClosingDate!.month.toString().padLeft(2, '0')}-${sale.expectedClosingDate!.day.toString().padLeft(2, '0')}'
                        : 'N/A',
                    textPrimary,
                    textSecondary,
                  ),
                  _buildInfoRow(
                    'Created By',
                    sale.createdByUser?.name ?? 'N/A',
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
                  sale,
                  'lead',
                  primaryColor,
                  textPrimary,
                ),
                _buildStatusButton(
                  context,
                  sale,
                  'prospect',
                  primaryColor,
                  textPrimary,
                ),
                _buildStatusButton(
                  context,
                  sale,
                  'proposal',
                  primaryColor,
                  textPrimary,
                ),
                _buildStatusButton(
                  context,
                  sale,
                  'negotiation',
                  primaryColor,
                  textPrimary,
                ),
                _buildStatusButton(
                  context,
                  sale,
                  'closed_won',
                  cs.tertiary,
                  textPrimary,
                ),
                _buildStatusButton(
                  context,
                  sale,
                  'closed_lost',
                  cs.error,
                  textPrimary,
                ),
                _buildStatusButton(
                  context,
                  sale,
                  'disqualified',
                  cs.outline,
                  textPrimary,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Activity Section
            _buildActivitySection(
              context,
              sale.id,
              surfaceColor,
              textPrimary,
              textSecondary,
              primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivitySection(
    BuildContext context,
    String saleId,
    Color surfaceColor,
    Color textPrimary,
    Color textSecondary,
    Color primaryColor,
  ) {
    final activitiesAsync = ref.watch(saleActivitiesProvider(saleId));

    return activitiesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Text(
        'Error loading activities',
        style: TextStyle(color: textSecondary),
      ),
      data: (activities) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Activities',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showAddActivityDialog(context, saleId),
                  icon: Icon(Icons.add, size: 18, color: primaryColor),
                  label: Text(
                    'Add Activity',
                    style: TextStyle(color: primaryColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (activities.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'No activities yet',
                    style: TextStyle(color: textSecondary),
                  ),
                ),
              )
            else
              ...activities.map(
                (activity) => _buildActivityItem(
                  activity,
                  surfaceColor,
                  textPrimary,
                  textSecondary,
                  primaryColor,
                ),
              ),
          ],
        );
      },
    );
  }

  void _showAddActivityDialog(
    BuildContext context,
    String saleId,
  ) {
    final titleController = TextEditingController();
    final noteController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: surfaceColor,
          title: Text('Add Activity', style: TextStyle(color: textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Title *',
                    labelStyle: TextStyle(color: textSecondary),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: noteController,
                  style: TextStyle(color: textPrimary),
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Note',
                    labelStyle: TextStyle(color: textSecondary),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) {
                      setDialogState(() => selectedDate = date);
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date',
                      labelStyle: TextStyle(color: textSecondary),
                      border: const OutlineInputBorder(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                          style: TextStyle(color: textPrimary),
                        ),
                        Icon(Icons.calendar_today, color: textSecondary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                if (titleController.text.isNotEmpty) {
                  try {
                    await ref
                        .read(saleRepositoryProvider)
                        .createSaleActivity(
                          saleId: saleId,
                          title: titleController.text,
                          date: selectedDate,
                          note: noteController.text.isNotEmpty
                              ? noteController.text
                              : null,
                        );
                    // Refresh activities
                    ref.invalidate(saleActivitiesProvider(saleId));
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                }
              },
              child: Text('Add', style: TextStyle(color: primaryColor)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(
    dynamic activity,
    Color surfaceColor,
    Color textPrimary,
    Color textSecondary,
    Color primaryColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  activity.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (activity.note != null && activity.note!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              activity.note!,
              style: TextStyle(color: textSecondary, fontSize: 14),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (activity.date != null)
                Text(
                  _formatDate(activity.date!),
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
              if (activity.createdByUser != null)
                Text(
                  'by ${activity.createdByUser.name}',
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
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
    Sale sale,
    String status,
    Color primaryColor,
    Color textPrimary,
  ) {
    final isSelected = sale.status == status;
    final cs = Theme.of(context).colorScheme;
    Color onBadge(Color bg) {
      final k = bg.toARGB32();
      if (k == cs.primary.toARGB32()) return cs.onPrimary;
      if (k == cs.tertiary.toARGB32()) return cs.onTertiary;
      if (k == cs.error.toARGB32()) return cs.onError;
      if (k == cs.outline.toARGB32()) return cs.onSurface;
      return cs.onPrimary;
    }

    return Container(
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
                  await ref
                      .read(salesProvider.notifier)
                      .changeSaleStatus(id: sale.id, status: status);
                  ref.invalidate(saleDetailProvider(sale.id));
                  if (status == 'closed_won' && context.mounted) {
                    HapticFeedback.mediumImpact();
                    setState(() => _celebrating = true);
                    _confettiController.play();
                    await Future.delayed(const Duration(milliseconds: 2800));
                    if (mounted) setState(() => _celebrating = false);
                  }
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              _getStatusDisplayText(status),
              style: TextStyle(
                color: isSelected ? onBadge(primaryColor) : textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getStatusDisplayText(String status) {
    switch (status) {
      case 'closed_won':
        return 'Closed Won';
      case 'closed_lost':
        return 'Closed Lost';
      default:
        return status.substring(0, 1).toUpperCase() + status.substring(1);
    }
  }

  void _showDeleteDialog(BuildContext context, Sale? sale) {
    if (sale == null) return;

    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final surfaceColor = AppThemeColors.surfaceColor(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        title: Text('Delete Deal', style: TextStyle(color: textPrimary)),
        content: Text(
          'Are you sure you want to delete "${sale.prospect}"? This action cannot be undone.',
          style: TextStyle(color: textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(salesProvider.notifier).deleteSale(sale.id);
              // Invalidate the sales provider to refresh the list
              ref.invalidate(salesProvider);
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class SaleFormPage extends ConsumerStatefulWidget {
  final Sale? sale;

  const SaleFormPage({super.key, this.sale});

  @override
  ConsumerState<SaleFormPage> createState() => _SaleFormPageState();
}

class _SaleFormPageState extends ConsumerState<SaleFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _prospectController;
  late TextEditingController _revenueController;
  late TextEditingController _closingDateController;
  late ConfettiController _confettiController;
  String _category = 'warm';
  String _status = 'lead';
  String? _selectedCompanyId;
  bool _isLoading = false;
  bool _celebrating = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _prospectController = TextEditingController(
      text: widget.sale?.prospect ?? '',
    );
    _revenueController = TextEditingController(
      text: widget.sale?.expectedRevenue?.toString() ?? '',
    );
    _closingDateController = TextEditingController(
      text: widget.sale?.expectedClosingDate != null
          ? '${widget.sale!.expectedClosingDate!.year}-${widget.sale!.expectedClosingDate!.month.toString().padLeft(2, '0')}-${widget.sale!.expectedClosingDate!.day.toString().padLeft(2, '0')}'
          : '',
    );
    if (widget.sale != null) {
      _category = widget.sale!.category ?? 'warm';
      _status = widget.sale!.status;
      _selectedCompanyId = widget.sale!.companyId;
    }

    // Load companies and users for the form
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(companiesProvider.notifier).loadCompanies();
      ref.read(usersProvider.notifier).loadUsers();
      ref.read(currenciesProvider.notifier).loadCurrencies();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _prospectController.dispose();
    _revenueController.dispose();
    _closingDateController.dispose();
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

  Future<void> _saveSale() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (widget.sale == null) {
        // Create new sale - need companyId
        if (_selectedCompanyId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a company')),
          );
          setState(() => _isLoading = false);
          return;
        }

        // Get the current user ID
        final currentUserId = ref.read(currentUserIdProvider);

        // If current user exists, set them as the KAM of the selected company
        if (currentUserId != null) {
          try {
            await ref
                .read(companiesProvider.notifier)
                .updateCompany(
                  id: _selectedCompanyId!,
                  kamUserId: currentUserId,
                );
          } catch (e) {
            // Continue even if KAM update fails
          }
        }

        // Create the deal with current user as createdByUserId
        await ref
            .read(salesProvider.notifier)
            .createSale(
              companyId: _selectedCompanyId!,
              prospect: _prospectController.text,
              expectedClosingDate:
                  DateTime.tryParse(_closingDateController.text) ??
                  DateTime.now(),
              category: _category,
              expectedRevenue: double.tryParse(_revenueController.text),
              status: _status,
              createdByUserId: currentUserId,
            );

        if (!mounted) return;
        HapticFeedback.mediumImpact();
        setState(() {
          _isLoading = false;
          _celebrating = true;
        });
        _confettiController.play();
        await Future.delayed(const Duration(milliseconds: 2800));
        if (mounted) {
          Navigator.pop(context);
        }
        return;
      }

      // Update existing sale
      await ref
          .read(salesProvider.notifier)
          .updateSale(
            id: widget.sale!.id,
            prospect: _prospectController.text,
            category: _category,
            expectedRevenue: double.tryParse(_revenueController.text),
            expectedClosingDate: DateTime.tryParse(
              _closingDateController.text,
            ),
            companyId: _selectedCompanyId,
          );

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
    final bgColor = AppThemeColors.backgroundColor(context);
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final borderColor = AppThemeColors.borderColor(context);

    return CelebrationShell(
      celebrating: _celebrating,
      confettiController: _confettiController,
      title: 'Congratulations!',
      message: 'Your new deal is in the pipeline.',
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: surfaceColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close, color: textPrimary),
            onPressed: _celebrating ? null : () => Navigator.pop(context),
          ),
          title: Text(
            widget.sale == null ? 'New Deal' : 'Edit Deal',
            style: TextStyle(color: textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: (_isLoading || _celebrating) ? null : _saveSale,
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
        body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Prospect Name
                Text(
                  'Prospect Name *',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _prospectController,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Enter prospect name',
                    hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6)),
                    filled: true,
                    fillColor: surfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter prospect name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Company (for new and existing deals)
                Text(
                  'Company *',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Consumer(
                  builder: (context, ref, child) {
                    final companiesState = ref.watch(companiesProvider);
                    return SearchableDropdown<String>(
                      items: companiesState.companies.map((c) => c.id).toList(),
                      value: _selectedCompanyId,
                      hintText: 'Select company',
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
                        setState(() => _selectedCompanyId = value);
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please select a company';
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
                const SizedBox(height: 20),

                // Expected Revenue
                Text(
                  'Expected Revenue',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _revenueController,
                  style: TextStyle(color: textPrimary),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Enter expected revenue',
                    hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6)),
                    prefixText: '\$ ',
                    prefixStyle: TextStyle(color: textPrimary),
                    filled: true,
                    fillColor: surfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Expected Closing Date
                Text(
                  'Expected Closing Date',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _closingDateController,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    hintText: 'YYYY-MM-DD',
                    hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6)),
                    filled: true,
                    fillColor: surfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    suffixIcon: Icon(
                      Icons.calendar_today,
                      color: textSecondary,
                    ),
                  ),
                  readOnly: true,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _closingDateController.text.isNotEmpty
                          ? DateTime.tryParse(_closingDateController.text) ??
                                DateTime.now()
                          : DateTime.now(),
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 365),
                      ),
                      lastDate: DateTime.now().add(
                        const Duration(days: 365 * 5),
                      ),
                    );
                    if (date != null) {
                      setState(() {
                        _closingDateController.text =
                            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                      });
                    }
                  },
                ),
                const SizedBox(height: 20),

                // Category
                Text(
                  'Category',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  isExpanded: true,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: surfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                  dropdownColor: surfaceColor,
                  items: const [
                    DropdownMenuItem(value: 'hot', child: Text('Hot')),
                    DropdownMenuItem(value: 'warm', child: Text('Warm')),
                    DropdownMenuItem(value: 'cold', child: Text('Cold')),
                  ],
                  onChanged: (value) {
                    setState(() => _category = value ?? 'warm');
                  },
                ),
                const SizedBox(height: 20),

                // Status
                if (widget.sale == null) ...[
                  Text(
                    'Status',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: surfaceColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                    ),
                    dropdownColor: surfaceColor,
                    items: const [
                      DropdownMenuItem(value: 'lead', child: Text('Lead')),
                      DropdownMenuItem(
                        value: 'prospect',
                        child: Text('Prospect'),
                      ),
                      DropdownMenuItem(
                        value: 'proposal',
                        child: Text('Proposal'),
                      ),
                      DropdownMenuItem(
                        value: 'negotiation',
                        child: Text('Negotiation'),
                      ),
                      DropdownMenuItem(
                        value: 'closed_won',
                        child: Text('Closed Won'),
                      ),
                      DropdownMenuItem(
                        value: 'closed_lost',
                        child: Text('Closed Lost'),
                      ),
                      DropdownMenuItem(
                        value: 'disqualified',
                        child: Text('Disqualified'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _status = value ?? 'lead');
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}
