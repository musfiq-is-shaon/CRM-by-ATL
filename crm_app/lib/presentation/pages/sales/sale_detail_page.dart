import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../data/models/sale_model.dart';
import '../../providers/sale_provider.dart';
import '../../providers/company_provider.dart';
import '../../providers/user_provider.dart';
import '../../../data/repositories/sale_repository.dart';
import '../../widgets/crm_card.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/searchable_dropdown.dart';
import '../companies/companies_list_page.dart';

class SaleDetailPage extends ConsumerWidget {
  final String saleId;

  const SaleDetailPage({super.key, required this.saleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saleAsync = ref.watch(saleDetailProvider(saleId));

    final bgColor = AppThemeColors.backgroundColor(context);
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final primaryColor = const Color(0xFF2563EB);

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
      data: (sale) => _buildContent(
        context,
        ref,
        sale,
        bgColor,
        surfaceColor,
        textPrimary,
        textSecondary,
        primaryColor,
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    Sale sale,
    Color bgColor,
    Color surfaceColor,
    Color textPrimary,
    Color textSecondary,
    Color primaryColor,
  ) {
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
            icon: Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _showDeleteDialog(context, ref, sale),
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
                  ref,
                  sale,
                  'lead',
                  primaryColor,
                  textPrimary,
                  textSecondary,
                  surfaceColor,
                ),
                _buildStatusButton(
                  context,
                  ref,
                  sale,
                  'prospect',
                  primaryColor,
                  textPrimary,
                  textSecondary,
                  surfaceColor,
                ),
                _buildStatusButton(
                  context,
                  ref,
                  sale,
                  'proposal',
                  primaryColor,
                  textPrimary,
                  textSecondary,
                  surfaceColor,
                ),
                _buildStatusButton(
                  context,
                  ref,
                  sale,
                  'negotiation',
                  primaryColor,
                  textPrimary,
                  textSecondary,
                  surfaceColor,
                ),
                _buildStatusButton(
                  context,
                  ref,
                  sale,
                  'closed_won',
                  const Color(0xFF10B981),
                  textPrimary,
                  textSecondary,
                  surfaceColor,
                ),
                _buildStatusButton(
                  context,
                  ref,
                  sale,
                  'closed_lost',
                  const Color(0xFFEF4444),
                  textPrimary,
                  textSecondary,
                  surfaceColor,
                ),
                _buildStatusButton(
                  context,
                  ref,
                  sale,
                  'disqualified',
                  const Color(0xFF6B7280),
                  textPrimary,
                  textSecondary,
                  surfaceColor,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Activity Section
            _buildActivitySection(
              context,
              ref,
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
    WidgetRef ref,
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
                  onPressed: () => _showAddActivityDialog(context, ref, saleId),
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
                ),
              ),
          ],
        );
      },
    );
  }

  void _showAddActivityDialog(
    BuildContext context,
    WidgetRef ref,
    String saleId,
  ) {
    final titleController = TextEditingController();
    final noteController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final primaryColor = const Color(0xFF2563EB);

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
                  color: const Color(0xFF2563EB),
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
    WidgetRef ref,
    Sale sale,
    String status,
    Color primaryColor,
    Color textPrimary,
    Color textSecondary,
    Color surfaceColor,
  ) {
    final isSelected = sale.status == status;
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
                      .read(salesProvider.notifier)
                      .changeSaleStatus(id: sale.id, status: status);
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              _getStatusDisplayText(status),
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

  void _showDeleteDialog(BuildContext context, WidgetRef ref, Sale? sale) {
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
  String _category = 'warm';
  String _status = 'lead';
  String? _selectedCompanyId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
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
    });
  }

  @override
  void dispose() {
    _prospectController.dispose();
    _revenueController.dispose();
    _closingDateController.dispose();
    super.dispose();
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
            );
      } else {
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
    final companiesState = ref.watch(companiesProvider);

    final bgColor = AppThemeColors.backgroundColor(context);
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final borderColor = AppThemeColors.borderColor(context);
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
          widget.sale == null ? 'New Deal' : 'Edit Deal',
          style: TextStyle(color: textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveSale,
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
                    hintStyle: TextStyle(color: textSecondary.withOpacity(0.6)),
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
                        if (value == null) {
                          return 'Please select a company';
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
                    hintStyle: TextStyle(color: textSecondary.withOpacity(0.6)),
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
                    hintStyle: TextStyle(color: textSecondary.withOpacity(0.6)),
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
                  value: _category,
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
                    value: _status,
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
    );
  }
}
