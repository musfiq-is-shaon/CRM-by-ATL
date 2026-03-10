import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../data/models/company_model.dart';
import '../../providers/contact_provider.dart';
import '../../providers/company_provider.dart';
import '../../widgets/crm_card.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/error_widget.dart' as app_widgets;
import '../../widgets/searchable_dropdown.dart';
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
    final contactsState = ref.watch(contactsProvider);

    final bgColor = AppThemeColors.backgroundColor(context);
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final textTertiary = AppThemeColors.textTertiaryColor(context);
    final borderColor = AppThemeColors.borderColor(context);
    final primaryColor = const Color(0xFF2563EB);
    final secondaryColor = const Color(0xFF10B981);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        title: Text('Contacts', style: TextStyle(color: textPrimary)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: textPrimary),
                    onChanged: (value) {
                      ref.read(contactsProvider.notifier).setSearchQuery(value);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search contacts...',
                      hintStyle: TextStyle(color: textTertiary),
                      prefixIcon: Icon(Icons.search, color: textSecondary),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: textSecondary),
                              onPressed: () {
                                _searchController.clear();
                                ref
                                    .read(contactsProvider.notifier)
                                    .setSearchQuery(null);
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: surfaceColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
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
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.filter_list, color: textPrimary),
                    onPressed: () => _showFilterDialog(context),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: contactsState.isLoading
                ? const LoadingWidget()
                : contactsState.filteredContacts.isEmpty
                ? app_widgets.EmptyStateWidget(
                    title: 'No contacts found',
                    subtitle: 'Add your first contact',
                    icon: Icons.people_outline,
                    buttonText: 'Add Contact',
                    onButtonPressed: () {},
                  )
                : RefreshIndicator(
                    onRefresh: () =>
                        ref.read(contactsProvider.notifier).loadContacts(),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: contactsState.filteredContacts.length,
                      itemBuilder: (context, index) {
                        final contact = contactsState.filteredContacts[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: CRMCard(
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
                              children: [
                                AvatarWidget(name: contact.name, size: 50),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        contact.name,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (contact.designation != null)
                                        Text(
                                          contact.designation!,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: textSecondary,
                                          ),
                                        ),
                                      if (contact.company != null)
                                        Text(
                                          contact.company!.name,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: textTertiary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                Column(
                                  children: [
                                    if (contact.mobile != null)
                                      IconButton(
                                        icon: const Icon(Icons.phone_outlined),
                                        color: primaryColor,
                                        iconSize: 20,
                                        onPressed: () =>
                                            _makeCall(contact.mobile!),
                                      ),
                                    if (contact.email != null)
                                      IconButton(
                                        icon: const Icon(Icons.email_outlined),
                                        color: secondaryColor,
                                        iconSize: 20,
                                        onPressed: () =>
                                            _sendEmail(contact.email!),
                                      ),
                                  ],
                                ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ContactFormPage()),
          );
        },
        backgroundColor: primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    final contactsState = ref.read(contactsProvider);
    final companiesState = ref.read(companiesProvider);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final primaryColor = const Color(0xFF2563EB);
    final surfaceColor = AppThemeColors.surfaceColor(context);

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
                      border: Border.all(color: textSecondary.withOpacity(0.3)),
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
                        foregroundColor: Colors.white,
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
