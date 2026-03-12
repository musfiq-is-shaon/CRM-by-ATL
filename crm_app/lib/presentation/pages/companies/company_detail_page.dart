import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../data/models/company_model.dart';
import '../../providers/company_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/crm_card.dart';
import '../../widgets/loading_widget.dart';

class CompanyDetailPage extends ConsumerWidget {
  final String companyId;

  const CompanyDetailPage({super.key, required this.companyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companiesState = ref.watch(companiesProvider);
    final company = companiesState.companies
        .where((c) => c.id == companyId)
        .firstOrNull;

    final bgColor = AppThemeColors.backgroundColor(context);
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final primaryColor = const Color(0xFF2563EB);
    final errorColor = const Color(0xFFEF4444);
    final accentColor = const Color(0xFF8B5CF6);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Company Details', style: TextStyle(color: textPrimary)),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: textPrimary),
            onPressed: company != null
                ? () {
                    _showEditCompanyDialog(context, ref, company);
                  }
                : null,
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: errorColor),
            onPressed: company != null
                ? () {
                    _showDeleteConfirmation(context, ref, company);
                  }
                : null,
          ),
        ],
      ),
      body: company == null
          ? const Center(child: LoadingWidget())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Company Header
                  CRMCard(
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text(
                              company.name.isNotEmpty
                                  ? company.name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          company.name,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (company.location != null ||
                            company.country != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                [company.location, company.country]
                                    .where((e) => e != null && e.isNotEmpty)
                                    .join(', '),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (company.kamUser != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person_outline,
                                  size: 16,
                                  color: accentColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'KAM: ${company.kamUser!.name}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: accentColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Company Information
                  Text(
                    'Company Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CRMCard(
                    child: Column(
                      children: [
                        if (company.location != null)
                          _buildInfoRow(
                            Icons.location_on_outlined,
                            'Location',
                            company.location!,
                            primaryColor,
                            textPrimary,
                            textSecondary,
                          ),
                        if (company.country != null)
                          _buildInfoRow(
                            Icons.public_outlined,
                            'Country',
                            company.country!,
                            primaryColor,
                            textPrimary,
                            textSecondary,
                          ),
                        if (company.kamUser != null)
                          _buildInfoRow(
                            Icons.person_outlined,
                            'Key Account Manager',
                            company.kamUser!.name,
                            primaryColor,
                            textPrimary,
                            textSecondary,
                          ),
                        _buildInfoRow(
                          Icons.calendar_today_outlined,
                          'Created',
                          company.createdAt != null
                              ? _formatDate(company.createdAt!)
                              : 'N/A',
                          primaryColor,
                          textPrimary,
                          textSecondary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    Color primaryColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: primaryColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showEditCompanyDialog(
    BuildContext context,
    WidgetRef ref,
    Company company,
  ) {
    final usersState = ref.read(usersProvider);
    final nameController = TextEditingController(text: company.name);
    final locationController = TextEditingController(text: company.location);
    final countryController = TextEditingController(text: company.country);
    String? selectedKamUserId = company.kamUserId;

    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final surfaceColor = AppThemeColors.surfaceColor(context);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: surfaceColor,
          title: Text('Edit Company', style: TextStyle(color: textPrimary)),
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
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: locationController,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Location',
                    labelStyle: TextStyle(color: textSecondary),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: countryController,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Country',
                    labelStyle: TextStyle(color: textSecondary),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedKamUserId,
                  decoration: InputDecoration(
                    labelText: 'KAM (Key Account Manager)',
                    labelStyle: TextStyle(color: textSecondary),
                    border: const OutlineInputBorder(),
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
              child: Text('Cancel', style: TextStyle(color: textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  await ref
                      .read(companiesProvider.notifier)
                      .updateCompany(
                        id: company.id,
                        name: nameController.text,
                        location: locationController.text.isNotEmpty
                            ? locationController.text
                            : null,
                        country: countryController.text.isNotEmpty
                            ? countryController.text
                            : null,
                        kamUserId: selectedKamUserId,
                      );
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    Company company,
  ) {
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final errorColor = const Color(0xFFEF4444);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        title: Text('Delete Company', style: TextStyle(color: textPrimary)),
        content: Text(
          'Are you sure you want to delete "${company.name}"? This action cannot be undone.',
          style: TextStyle(color: textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              await ref
                  .read(companiesProvider.notifier)
                  .deleteCompany(company.id);
              if (context.mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to list
              }
            },
            child: Text('Delete', style: TextStyle(color: errorColor)),
          ),
        ],
      ),
    );
  }
}
