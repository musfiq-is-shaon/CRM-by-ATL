import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/rbac_page_keys.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/company_model.dart';
import '../../providers/contact_provider.dart';
import '../../providers/rbac_provider.dart'
    show rbacAccessDigestProvider, rbacModuleAdminProvider;
import '../../providers/company_provider.dart';
import '../../widgets/crm_card.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/error_widget.dart' as app_widgets;
import '../../widgets/searchable_dropdown.dart';
import '../../widgets/app_search_filter_bar.dart';
import 'business_card_scan_flow.dart';
import 'contact_detail_page.dart';

class ContactsListPage extends ConsumerStatefulWidget {
  const ContactsListPage({super.key});

  @override
  ConsumerState<ContactsListPage> createState() => _ContactsListPageState();
}

class _ContactsListPageState extends ConsumerState<ContactsListPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(contactsProvider.notifier).loadContacts();
      ref.read(companiesProvider.notifier).loadCompanies();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(rbacAccessDigestProvider);
    ref.watch(rbacModuleAdminProvider(RbacPageKey.contacts));
    final contactsState = ref.watch(contactsProvider);
    final companiesState = ref.watch(companiesProvider);

    final bgColor = AppThemeColors.backgroundColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final cs = Theme.of(context).colorScheme;
    final primaryColor = cs.primary;
    final secondaryColor = cs.tertiary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppThemeColors.appBarTitle(
        context,
        'Contacts',
        actions: [
          IconButton(
            tooltip: 'Scan business card',
            onPressed: _scanBusinessCard,
            icon: Icon(Icons.document_scanner_outlined, color: textPrimary),
          ),
          IconButton(
            tooltip: 'Add contact',
            onPressed: _openAddContact,
            icon: Icon(Icons.add, color: textPrimary),
          ),
        ],
      ),
      body: Column(
        children: [
          AppSearchFilterBar(
            controller: _searchController,
            hintText: 'Search contacts...',
            padding: AppThemeColors.listHeaderPadding,
            onChanged: (value) {
              ref.read(contactsProvider.notifier).setSearchQuery(value);
            },
            onClear: () {
              _searchController.clear();
              ref.read(contactsProvider.notifier).setSearchQuery(null);
              setState(() {});
            },
            onFilterTap: () => _showFilterDialog(context),
          ),
          Expanded(
            child: contactsState.isLoading
                ? const ListSkeletonLoader(
                    itemCount: 8,
                    padding: AppThemeColors.pagePaddingHorizontal,
                  )
                : contactsState.filteredContacts.isEmpty
                ? app_widgets.EmptyStateWidget(
                    title: 'No contacts found',
                    subtitle: 'Add your first contact',
                    icon: Icons.people_outline,
                    buttonText: 'Add Contact',
                    onButtonPressed: _openAddContact,
                  )
                : RefreshIndicator(
                    onRefresh: () =>
                        ref.read(contactsProvider.notifier).loadContacts(),
                    child: ListView.builder(
                      padding: AppThemeColors.listPagePadding,
                      itemCount: contactsState.filteredContacts.length,
                      itemBuilder: (context, index) {
                        final contact = contactsState.filteredContacts[index];
                        final companyName = contact.companyDisplayName(
                          companiesState.companies,
                        );
                        return Padding(
                          padding: AppThemeColors.cardListItemMargin,
                          child: CRMCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.cardPadding,
                              vertical: AppSpacing.md,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ContactDetailPage(contactId: contact.id),
                                ),
                              );
                            },
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                AvatarWidget(
                                  name: contact.name,
                                  size: AppSizes.iconChip,
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        contact.name,
                                        style: AppTypography.cardTitle(context)
                                            ?.copyWith(color: textPrimary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (contact.designation != null &&
                                          contact.designation!.isNotEmpty) ...[
                                        const SizedBox(height: AppSpacing.xs),
                                        Text(
                                          contact.designation!,
                                          style: AppTypography.bodySmall(context),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      if (companyName != null) ...[
                                        const SizedBox(height: AppSpacing.xs),
                                        Text(
                                          companyName,
                                          style: AppTypography.caption(context),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (contact.mobile != null ||
                                    contact.email != null) ...[
                                  const SizedBox(width: AppSpacing.xs),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (contact.mobile != null)
                                        _ContactActionIcon(
                                          icon: Icons.phone_outlined,
                                          color: primaryColor,
                                          tooltip: 'Call',
                                          onPressed: () =>
                                              _makeCall(contact.mobile!),
                                        ),
                                      if (contact.email != null)
                                        _ContactActionIcon(
                                          icon: Icons.email_outlined,
                                          color: secondaryColor,
                                          tooltip: 'Email',
                                          onPressed: () =>
                                              _sendEmail(contact.email!),
                                        ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _openAddContact() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ContactFormPage()),
    );
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
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ContactFormPage(initialScan: card),
            ),
          );
        }
      },
    );
  }

  void _showFilterDialog(BuildContext context) {
    final contactsState = ref.read(contactsProvider);
    final companiesState = ref.read(companiesProvider);
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    String? selectedCompanyId = contactsState.companyIdFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppThemeColors.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Filter Contacts',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          ref.read(contactsProvider.notifier).clearFilters();
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Clear All',
                          style: TextStyle(color: primaryColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Company',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: textSecondary.withValues(alpha: 0.3)),
                    ),
                    child: SearchableDropdown<Company>(
                      items: companiesState.companies,
                      value: selectedCompanyId != null
                          ? companiesState.companies
                                .where((c) => c.id == selectedCompanyId)
                                .firstOrNull
                          : null,
                      hintText: 'All Companies',
                      labelText: 'Company',
                      dropdownColor: surfaceColor,
                      textColor: textPrimary,
                      hintColor: textSecondary,
                      itemLabelBuilder: (company) => company.name,
                      onChanged: (company) {
                        setModalState(() => selectedCompanyId = company?.id);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        ref
                            .read(contactsProvider.notifier)
                            .setCompanyFilter(selectedCompanyId);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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

class _ContactActionIcon extends StatelessWidget {
  const _ContactActionIcon({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: AppSizes.iconChipIcon),
      color: color,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(
        minWidth: 36,
        minHeight: 36,
      ),
      onPressed: onPressed,
    );
  }
}
