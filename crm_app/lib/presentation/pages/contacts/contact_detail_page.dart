import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/rbac_page_keys.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/repositories/company_repository.dart';
import '../../../data/models/contact_model.dart';
import '../../../core/utils/business_card_ocr_canonical.dart';
import '../../../core/utils/company_name_match.dart';
import '../../providers/contact_provider.dart';
import '../../providers/rbac_provider.dart'
    show rbacAccessDigestProvider, rbacModuleAdminProvider;
import '../../providers/company_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/crm_card.dart';
import '../../widgets/app_section_header.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/searchable_dropdown.dart';
import '../../widgets/create_company_dialog.dart';

import 'business_card_scan_flow.dart';

class ContactDetailPage extends ConsumerWidget {
  final String contactId;

  const ContactDetailPage({super.key, required this.contactId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(rbacAccessDigestProvider);
    ref.watch(rbacModuleAdminProvider(RbacPageKey.contacts));
    final contactsState = ref.watch(contactsProvider);
    final companiesState = ref.watch(companiesProvider);
    final contact = contactsState.contacts
        .where((c) => c.id == contactId)
        .firstOrNull;
    final companyName =
        contact?.companyDisplayName(companiesState.companies);

    final bgColor = AppThemeColors.backgroundColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final errorColor = Theme.of(context).colorScheme.error;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppThemeColors.appBarTitle(
        context,
        'Contact Details',
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: textPrimary),
            onPressed: contact != null
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ContactFormPage(contact: contact),
                      ),
                    );
                  }
                : null,
          ),
          IconButton(
            tooltip: 'Delete contact',
            icon: Icon(Icons.delete_outline, color: errorColor),
            onPressed: contact != null
                ? () => _showDeleteConfirmation(context, ref, contact)
                : null,
          ),
        ],
      ),
      body: contact == null
          ? const DetailSkeleton()
          : SingleChildScrollView(
              padding: AppThemeColors.pagePaddingAll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Contact Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: AppThemeColors.heroSurface(context),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        AppThemeColors.iconChip(
                          context,
                          icon: Icons.person_outline,
                          accent: primaryColor,
                          size: 64,
                          iconSize: 32,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          contact.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        // Designation with consistent display
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xxs + 2,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            contact.designation ?? 'No Designation',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: contact.designation != null
                                  ? primaryColor
                                  : textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        // Company with icon
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.business,
                              size: 16,
                              color: textSecondary,
                            ),
                            const SizedBox(width: AppSpacing.xxs),
                            Flexible(
                              child: Text(
                                companyName ?? 'No Company',
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: companyName != null
                                      ? primaryColor
                                      : textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Quick Actions
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.phone,
                          label: 'Call',
                          primaryColor: primaryColor,
                          textPrimary: textPrimary,
                          onTap: contact.mobile != null
                              ? () => _makeCall(contact.mobile!)
                              : null,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.email,
                          label: 'Email',
                          primaryColor: primaryColor,
                          textPrimary: textPrimary,
                          onTap: contact.email != null
                              ? () => _sendEmail(contact.email!)
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Contact Info
                  AppSectionHeader(title: 'Contact Information'),
                  const SizedBox(height: AppSpacing.sm),
                  CRMCard(
                    child: Column(
                      children: [
                        if (contact.email != null)
                          _buildInfoRow(
                            Icons.email_outlined,
                            'Email',
                            contact.email!,
                            primaryColor,
                            textPrimary,
                            textSecondary,
                          ),
                        if (contact.mobile != null)
                          _buildInfoRow(
                            Icons.phone_outlined,
                            'Mobile',
                            contact.mobile!,
                            primaryColor,
                            textPrimary,
                            textSecondary,
                          ),
                        if (companyName != null)
                          _buildInfoRow(
                            Icons.business_outlined,
                            'Company',
                            companyName,
                            primaryColor,
                            textPrimary,
                            textSecondary,
                          ),
                        // Show placeholder if no contact info
                        if (contact.email == null &&
                            contact.mobile == null &&
                            companyName == null)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                            ),
                            child: Text(
                              'No contact information available',
                              style: TextStyle(
                                fontSize: 14,
                                color: textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    Contact contact,
  ) {
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        title: Text('Delete Contact', style: TextStyle(color: textPrimary)),
        content: Text(
          'Are you sure you want to delete "${contact.name}"? This action cannot be undone.',
          style: TextStyle(color: textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(contactsProvider.notifier).deleteContact(contact.id);
              if (context.mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Back to list
              }
            },
            child: Text('Delete', style: TextStyle(color: cs.error)),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: primaryColor, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
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

  Future<void> _makeCall(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _sendEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color primaryColor;
  final Color textPrimary;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.primaryColor,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    final bg = enabled ? primaryColor : cs.surfaceContainerHighest;
    final fg =
        enabled ? cs.onPrimary : cs.onSurface.withValues(alpha: 0.45);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: fg, size: 20),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ContactFormPage extends ConsumerStatefulWidget {
  final Contact? contact;
  final CanonicalBusinessCardContact? initialScan;

  const ContactFormPage({super.key, this.contact, this.initialScan});

  @override
  ConsumerState<ContactFormPage> createState() => _ContactFormPageState();
}

class _ContactFormPageState extends ConsumerState<ContactFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _mobileController;
  late TextEditingController _designationController;
  String? _selectedCompanyId;
  bool _isLoading = false;
  String? _ocrCompanySuggestion;
  String? _ocrCompanyLocationSuggestion;
  List<CompanyNameMatchCandidate> _ocrSimilarCompanies = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.contact?.name ?? '');
    _emailController = TextEditingController(text: widget.contact?.email ?? '');
    _mobileController = TextEditingController(
      text: widget.contact?.mobile ?? '',
    );
    _designationController = TextEditingController(
      text: widget.contact?.designation ?? '',
    );
    _selectedCompanyId = widget.contact?.companyId;

    // Preload dropdown data in parallel so create-company opens instantly.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final loads = <Future<void>>[
        ref.read(currenciesProvider.notifier).loadCurrencies(),
        ref.read(usersProvider.notifier).loadUsers(),
      ];
      if (ref.read(companiesProvider).companies.isEmpty) {
        loads.add(ref.read(companiesProvider.notifier).loadCompanies());
      }
      await Future.wait(loads);
      final scan = widget.initialScan;
      if (scan != null && mounted) {
        await _applyBusinessCardScan(scan);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _designationController.dispose();
    super.dispose();
  }

  Future<void> _showCreateCompanyDialog(
    BuildContext context, {
    String? initialName,
    String? initialLocation,
  }) async {
    final result = await showCreateCompanyDialog(
      context,
      ref,
      initialName: initialName,
      initialLocation: initialLocation,
    );
    if (result != null && result.isNotEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      setState(() {
        _selectedCompanyId = result;
        _ocrCompanySuggestion = null;
        _ocrCompanyLocationSuggestion = null;
        _ocrSimilarCompanies = [];
      });
    }
  }

  Future<void> _applyBusinessCardScan(CanonicalBusinessCardContact card) async {
    if (card.name != null) _nameController.text = card.name!;
    if (card.designation != null) {
      _designationController.text = card.designation!;
    }
    if (card.mobile != null) _mobileController.text = card.mobile!;
    if (card.email != null) _emailController.text = card.email!;

    final matchResult = await ref
        .read(companyRepositoryProvider)
        .matchCompaniesByName(card.companyName);

    setState(() {
      _ocrCompanySuggestion = card.companyName;
      _ocrCompanyLocationSuggestion = card.companyLocation;
      _ocrSimilarCompanies = matchResult.suggestions;
      if (matchResult.autoSelectId != null) {
        _selectedCompanyId = matchResult.autoSelectId;
        _ocrSimilarCompanies = [];
        _ocrCompanySuggestion = null;
      }
    });

    if (!mounted) return;

    final filled = card.toFieldMap().entries
        .where((e) => e.value != null)
        .map((e) => e.key)
        .join(', ');

    if (matchResult.autoSelectId == null && card.companyName != null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (matchResult.hasSuggestions) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Filled $filled. Similar spellings found for "${card.companyName}" — tap one below.',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Filled $filled. Company "${card.companyName}" not found — tap + on Company to create it.',
            ),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Create',
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _showCreateCompanyDialog(
                    context,
                    initialName: card.companyName,
                    initialLocation: card.companyLocation,
                  );
                });
              },
            ),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Filled from card: $filled')),
      );
    }
  }

  Future<void> _scanBusinessCard() async {
    await BusinessCardScanFlow.showSourceSheet(
      context,
      onSource: (source) async {
        final card = await BusinessCardScanFlow.pickAndExtract(
          context,
          source: source,
        );
        if (card != null && mounted) {
          await _applyBusinessCardScan(card);
        }
      },
    );
  }

  Future<void> _saveContact() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (widget.contact == null) {
        // Create new contact
        if (_selectedCompanyId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a company')),
          );
          setState(() => _isLoading = false);
          return;
        }

        await ref
            .read(contactsProvider.notifier)
            .createContact(
              name: _nameController.text,
              companyId: _selectedCompanyId!,
              email: _emailController.text.isEmpty
                  ? null
                  : _emailController.text,
              mobile: _mobileController.text.isEmpty
                  ? null
                  : _mobileController.text,
              designation: _designationController.text.isEmpty
                  ? null
                  : _designationController.text,
            );
      } else {
        // Update existing contact
        await ref
            .read(contactsProvider.notifier)
            .updateContact(
              id: widget.contact!.id,
              name: _nameController.text,
              email: _emailController.text.isEmpty
                  ? null
                  : _emailController.text,
              mobile: _mobileController.text.isEmpty
                  ? null
                  : _mobileController.text,
              designation: _designationController.text.isEmpty
                  ? null
                  : _designationController.text,
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

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppThemeColors.appBarTitle(
        context,
        widget.contact == null ? 'New Contact' : 'Edit Contact',
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Scan business card',
            onPressed: _isLoading ? null : _scanBusinessCard,
            icon: const Icon(Icons.document_scanner_outlined),
          ),
          TextButton(
            onPressed: _isLoading ? null : _saveContact,
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
          padding: AppThemeColors.pagePaddingAll,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_ocrCompanySuggestion != null &&
                    _selectedCompanyId == null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .tertiaryContainer
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.business_outlined,
                              size: 20,
                              color: Theme.of(context).colorScheme.tertiary,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                _ocrSimilarCompanies.isNotEmpty
                                    ? 'OCR: $_ocrCompanySuggestion — similar spellings found, tap to pick:'
                                    : 'OCR company: $_ocrCompanySuggestion — select or create below.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textSecondary,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Dismiss',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              icon: Icon(
                                Icons.close,
                                size: 18,
                                color: textSecondary,
                              ),
                              onPressed: () {
                                setState(() {
                                  _ocrCompanySuggestion = null;
                                  _ocrCompanyLocationSuggestion = null;
                                  _ocrSimilarCompanies = [];
                                });
                              },
                            ),
                          ],
                        ),
                        if (_ocrSimilarCompanies.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: _ocrSimilarCompanies.map((candidate) {
                              return ActionChip(
                                label: Text(
                                  candidate.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: textPrimary,
                                  ),
                                ),
                                backgroundColor: surfaceColor,
                                side: BorderSide(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outline
                                      .withValues(alpha: 0.4),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _selectedCompanyId = candidate.id;
                                    _ocrCompanySuggestion = null;
                                    _ocrCompanyLocationSuggestion = null;
                                    _ocrSimilarCompanies = [];
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                // Name Field (Required)
                TextFormField(
                  controller: _nameController,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Name *',
                    labelStyle: TextStyle(color: textSecondary),
                    hintText: 'Enter contact name',
                    hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6)),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // Company Dropdown (Required)
                Consumer(
                  builder: (context, ref, child) {
                    final companiesState = ref.watch(companiesProvider);
                    return SearchableDropdown<String>(
                      key: ValueKey(
                        'company-${companiesState.companies.length}-$_selectedCompanyId',
                      ),
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
                          if (value != null) {
                            _ocrCompanySuggestion = null;
                            _ocrCompanyLocationSuggestion = null;
                            _ocrSimilarCompanies = [];
                          }
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Company is required';
                        }
                        return null;
                      },
                      onAddNew: () => _showCreateCompanyDialog(
                        context,
                        initialName: _ocrCompanySuggestion,
                        initialLocation: _ocrCompanyLocationSuggestion,
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // Designation Field
                TextFormField(
                  controller: _designationController,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Designation',
                    labelStyle: TextStyle(color: textSecondary),
                    hintText: 'e.g. Manager, Director',
                    hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6)),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Mobile Field
                TextFormField(
                  controller: _mobileController,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Mobile',
                    labelStyle: TextStyle(color: textSecondary),
                    hintText: '+1234567890',
                    hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6)),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: AppSpacing.md),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: textSecondary),
                    hintText: 'john@example.com',
                    hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6)),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
