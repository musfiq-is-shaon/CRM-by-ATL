import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../providers/company_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/currency_provider.dart';
import '../../widgets/crm_card.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/error_widget.dart' as app_widgets;
import '../../widgets/app_search_filter_bar.dart';
import '../../widgets/create_company_dialog.dart';
import 'company_detail_page.dart';

class CompaniesListPage extends ConsumerStatefulWidget {
  final bool openCreateDialog;

  const CompaniesListPage({super.key, this.openCreateDialog = false});

  @override
  ConsumerState<CompaniesListPage> createState() => _CompaniesListPageState();
}

class _CompaniesListPageState extends ConsumerState<CompaniesListPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(companiesProvider.notifier).loadCompanies();
      ref.read(usersProvider.notifier).loadUsers();
      ref.read(currenciesProvider.notifier).loadCurrencies();
      // Open create dialog if requested
      if (widget.openCreateDialog) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showCreateCompanyDialog(context);
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final companiesState = ref.watch(companiesProvider);

    final bgColor = AppThemeColors.backgroundColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final textTertiary = AppThemeColors.textTertiaryColor(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppThemeColors.appBarTitle(
        context,
        'Companies',
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateCompanyDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          AppSearchFilterBar(
            controller: _searchController,
            hintText: 'Search companies...',
            padding: AppThemeColors.listHeaderPadding,
            onChanged: (value) {
              ref.read(companiesProvider.notifier).setSearchQuery(value);
            },
            onClear: () {
              _searchController.clear();
              ref.read(companiesProvider.notifier).setSearchQuery(null);
              setState(() {});
            },
            onFilterTap: () => _showFilterDialog(context),
          ),
          Expanded(
            child: companiesState.isLoading
                ? const LoadingWidget()
                : companiesState.error != null
                ? app_widgets.ErrorWidget(
                    message: companiesState.error!,
                    onRetry: () =>
                        ref.read(companiesProvider.notifier).loadCompanies(),
                  )
                : companiesState.filteredCompanies.isEmpty
                ? const app_widgets.EmptyStateWidget(
                    title: 'No companies found',
                    subtitle: 'Add your first company',
                    icon: Icons.business_outlined,
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      await ref
                          .read(companiesProvider.notifier)
                          .loadCompanies();
                    },
                    child: ListView.builder(
                      padding: AppThemeColors.pagePaddingHorizontal,
                      itemCount: companiesState.filteredCompanies.length,
                      itemBuilder: (context, index) {
                        final company = companiesState.filteredCompanies[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: CRMCard(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      CompanyDetailPage(companyId: company.id),
                                ),
                              );
                            },
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      company.name.isNotEmpty
                                          ? company.name[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        company.name,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        [company.location, company.country]
                                            .where(
                                              (e) => e != null && e.isNotEmpty,
                                            )
                                            .join(', '),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: textSecondary,
                                        ),
                                      ),
                                      if (company.kamUser != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'KAM: ${company.kamUser!.name}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: primaryColor,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right, color: textTertiary),
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

  void _showFilterDialog(BuildContext context) {
    final companiesState = ref.read(companiesProvider);
    final usersState = ref.read(usersProvider);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    String? selectedCountry = companiesState.countryFilter;
    String? selectedKamUserId = companiesState.kamUserIdFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppThemeColors.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: AppThemeColors.pagePaddingAll,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter Companies',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      ref.read(companiesProvider.notifier).clearFilters();
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
                'Country',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected:
                        selectedCountry == null || selectedCountry!.isEmpty,
                    onSelected: (selected) {
                      setModalState(() => selectedCountry = null);
                    },
                    selectedColor: primaryColor.withValues(alpha: 0.2),
                    checkmarkColor: primaryColor,
                  ),
                  ...companiesState.availableCountries.map(
                    (country) => FilterChip(
                      label: Text(country),
                      selected: selectedCountry == country,
                      onSelected: (selected) {
                        setModalState(
                          () => selectedCountry = selected ? country : null,
                        );
                      },
                      selectedColor: primaryColor.withValues(alpha: 0.2),
                      checkmarkColor: primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'KAM (Key Account Manager)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected:
                        selectedKamUserId == null || selectedKamUserId!.isEmpty,
                    onSelected: (selected) {
                      setModalState(() => selectedKamUserId = null);
                    },
                    selectedColor: primaryColor.withValues(alpha: 0.2),
                    checkmarkColor: primaryColor,
                  ),
                  ...usersState.users.map(
                    (user) => FilterChip(
                      label: Text(user.name),
                      selected: selectedKamUserId == user.id,
                      onSelected: (selected) {
                        setModalState(
                          () => selectedKamUserId = selected ? user.id : null,
                        );
                      },
                      selectedColor: primaryColor.withValues(alpha: 0.2),
                      checkmarkColor: primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    ref
                        .read(companiesProvider.notifier)
                        .setCountryFilter(selectedCountry);
                    ref
                        .read(companiesProvider.notifier)
                        .setKamUserFilter(selectedKamUserId);
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
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateCompanyDialog(BuildContext context) async {
    await showCreateCompanyDialog(context, ref);
  }
}
