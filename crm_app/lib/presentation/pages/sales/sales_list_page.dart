import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../data/models/company_model.dart';
import '../../../data/models/user_model.dart';
import '../../providers/sale_provider.dart';
import '../../providers/company_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/crm_card.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/error_widget.dart' as app_widgets;
import '../../widgets/searchable_dropdown.dart';
import 'sale_detail_page.dart';

class SalesListPage extends ConsumerStatefulWidget {
  const SalesListPage({super.key});

  @override
  ConsumerState<SalesListPage> createState() => _SalesListPageState();
}

class _SalesListPageState extends ConsumerState<SalesListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  // Filter state
  String? _selectedStatus;
  String? _selectedCategory;
  String? _selectedCompanyId;
  String? _selectedRevenueRange;
  String? _selectedKamUserId;
  String _sortBy =
      'createdAt'; // createdAt, expectedClosingDate, expectedRevenue
  bool _sortAscending = false;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(salesProvider.notifier).loadSales();
      ref.read(companiesProvider.notifier).loadCompanies();
      ref.read(usersProvider.notifier).loadUsers();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final salesState = ref.watch(salesProvider);
    final companiesState = ref.watch(companiesProvider);
    final usersState = ref.watch(usersProvider);
    final bgColor = AppThemeColors.backgroundColor(context);
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final textTertiary = AppThemeColors.textTertiaryColor(context);
    final borderColor = AppThemeColors.borderColor(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    // Count active filters
    int activeFilterCount = 0;
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      activeFilterCount++;
    }
    if (_selectedCompanyId != null && _selectedCompanyId!.isNotEmpty) {
      activeFilterCount++;
    }
    if (_selectedRevenueRange != null && _selectedRevenueRange!.isNotEmpty) {
      activeFilterCount++;
    }
    if (_selectedKamUserId != null && _selectedKamUserId!.isNotEmpty) {
      activeFilterCount++;
    }
    if (_startDate != null || _endDate != null) {
      activeFilterCount++;
    }
    if (_sortBy != 'createdAt' || _sortAscending != false) {
      activeFilterCount++;
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        title: Text('Deals', style: TextStyle(color: textPrimary)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(118),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(color: textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search deals...',
                          hintStyle: TextStyle(color: textTertiary),
                          prefixIcon: Icon(Icons.search, color: textSecondary),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, color: textSecondary),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: borderColor.withValues(alpha: 0.6),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: borderColor.withValues(alpha: 0.45),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: primaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged: (value) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _showFilterDialog(
                          context,
                          companiesState,
                          usersState,
                        ),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Center(
                                child: Icon(
                                  Icons.filter_list,
                                  color: primaryColor,
                                ),
                              ),
                              if (activeFilterCount > 0)
                                Positioned(
                                  right: 4,
                                  top: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: primaryColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 14,
                                    ),
                                    child: Text(
                                      '$activeFilterCount',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.45),
              ),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                // Material 3 default is startOffset, which indents tabs; align flush left.
                tabAlignment: TabAlignment.start,
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsetsDirectional.only(
                  start: 12,
                  end: 16,
                ),
                automaticIndicatorColorAdjustment: false,
                labelColor: primaryColor,
                unselectedLabelColor: textSecondary,
                indicatorColor: primaryColor,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Lead'),
                  Tab(text: 'Prospect'),
                  Tab(text: 'Proposal'),
                  Tab(text: 'Negotiation'),
                  Tab(text: 'Closed Won'),
                  Tab(text: 'Closed Lost'),
                  Tab(text: 'Disqualified'),
                  Tab(text: 'All'),
                ],
                onTap: (index) {
                  final statuses = [
                    'lead',
                    'prospect',
                    'proposal',
                    'negotiation',
                    'closed_won',
                    'closed_lost',
                    'disqualified',
                    null,
                  ];
                  ref
                      .read(salesProvider.notifier)
                      .setStatusFilter(statuses[index]);
                  setState(() {
                    _selectedStatus = statuses[index];
                  });
                },
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSalesList(salesState, 'lead'),
          _buildSalesList(salesState, 'prospect'),
          _buildSalesList(salesState, 'proposal'),
          _buildSalesList(salesState, 'negotiation'),
          _buildSalesList(salesState, 'closed_won'),
          _buildSalesList(salesState, 'closed_lost'),
          _buildSalesList(salesState, 'disqualified'),
          _buildSalesList(salesState, null),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SaleFormPage()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSalesList(
    SalesState state,
    String? status,
  ) {
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final textTertiary = AppThemeColors.textTertiaryColor(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (state.isLoading) {
      return const LoadingWidget();
    }

    var sales = state.sales;
    if (status != null) {
      sales = sales.where((s) => s.status == status).toList();
    }

    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      sales = sales.where((s) {
        return s.prospect.toLowerCase().contains(query) ||
            (s.company?.name.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Apply local filters (from filter dialog)
    // Apply KAM filter
    if (_selectedKamUserId != null && _selectedKamUserId!.isNotEmpty) {
      sales = sales
          .where((s) => s.company?.kamUserId == _selectedKamUserId)
          .toList();
    }

    // Apply category filter from provider is already applied in filteredSales

    // Apply company filter
    if (_selectedCompanyId != null && _selectedCompanyId!.isNotEmpty) {
      sales = sales.where((s) => s.companyId == _selectedCompanyId).toList();
    }

    // Apply revenue range filter
    if (_selectedRevenueRange != null && _selectedRevenueRange!.isNotEmpty) {
      sales = sales.where((s) {
        final revenue = s.expectedRevenue ?? 0;
        switch (_selectedRevenueRange) {
          case '0-1000':
            return revenue >= 0 && revenue <= 1000;
          case '1000-5000':
            return revenue > 1000 && revenue <= 5000;
          case '5000-10000':
            return revenue > 5000 && revenue <= 10000;
          case '10000+':
            return revenue > 10000;
          default:
            return true;
        }
      }).toList();
    }

    // Apply date range filter
    if (_startDate != null || _endDate != null) {
      sales = sales.where((s) {
        if (s.expectedClosingDate == null) return false;
        if (_startDate != null &&
            s.expectedClosingDate!.isBefore(_startDate!)) {
          return false;
        }
        if (_endDate != null && s.expectedClosingDate!.isAfter(_endDate!)) {
          return false;
        }
        return true;
      }).toList();
    }

    // Apply sorting
    sales.sort((a, b) {
      int comparison;
      switch (_sortBy) {
        case 'expectedClosingDate':
          final aDate = a.expectedClosingDate ?? DateTime(1900);
          final bDate = b.expectedClosingDate ?? DateTime(1900);
          comparison = aDate.compareTo(bDate);
          break;
        case 'expectedRevenue':
          final aRevenue = a.expectedRevenue ?? 0;
          final bRevenue = b.expectedRevenue ?? 0;
          comparison = aRevenue.compareTo(bRevenue);
          break;
        case 'createdAt':
        default:
          final aCreated = a.createdAt ?? DateTime(1900);
          final bCreated = b.createdAt ?? DateTime(1900);
          comparison = aCreated.compareTo(bCreated);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    if (sales.isEmpty) {
      return app_widgets.EmptyStateWidget(
        title: 'No deals found',
        subtitle: status != null
            ? 'No ${status.replaceAll('_', ' ')} deals yet'
            : 'Create your first deal',
        icon: Icons.trending_up,
        buttonText: 'Add Deal',
        onButtonPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SaleFormPage()),
          );
        },
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(salesProvider.notifier).loadSales(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sales.length,
        itemBuilder: (context, index) {
          final sale = sales[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CRMCard(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SaleDetailPage(saleId: sale.id),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sale.prospect,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              sale.company?.name ?? 'No company',
                              style: TextStyle(
                                fontSize: 14,
                                color: textSecondary,
                              ),
                            ),
                            if (sale.company?.kamUser != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'KAM: ${sale.company!.kamUser!.name}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            sale.formattedRevenue,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (sale.category != null)
                            StatusBadge(
                              status: sale.category!,
                              type: 'category',
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      StatusBadge(status: sale.status, type: 'sale'),
                      const Spacer(),
                      if (sale.expectedClosingDate != null)
                        Text(
                          'Close: ${_formatDate(sale.expectedClosingDate!)}',
                          style: TextStyle(fontSize: 12, color: textTertiary),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showFilterDialog(
    BuildContext context,
    CompaniesState companiesState,
    UsersState usersState,
  ) {
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final borderColor = AppThemeColors.borderColor(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    // Local state for the dialog
    String? localSelectedStatus = _selectedStatus;
    String? localSelectedCategory = _selectedCategory;
    String? localSelectedCompanyId = _selectedCompanyId;
    String? localSelectedRevenueRange = _selectedRevenueRange;
    String? localSelectedKamUserId = _selectedKamUserId;
    String localSortBy = _sortBy;
    bool localSortAscending = _sortAscending;
    DateTime? localStartDate = _startDate;
    DateTime? localEndDate = _endDate;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setModalState) {
          final screenWidth = MediaQuery.of(context).size.width;
          final dialogWidth = screenWidth > 500 ? 450.0 : screenWidth * 0.9;

          return Dialog(
            backgroundColor: surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: SizedBox(
              width: dialogWidth > 400 ? 500 : dialogWidth * 0.95,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Filter & Sort Deals',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: textSecondary),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Sort Section
                      Text(
                        'Sort By',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: localSortBy,
                        isExpanded: true,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'createdAt',
                            child: Text('Date Created'),
                          ),
                          DropdownMenuItem(
                            value: 'expectedClosingDate',
                            child: Text('Closing Date'),
                          ),
                          DropdownMenuItem(
                            value: 'expectedRevenue',
                            child: Text('Revenue'),
                          ),
                        ],
                        onChanged: (value) {
                          setModalState(() => localSortBy = value!);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Status Filter
                      Text(
                        'Status',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: localSelectedStatus,
                        isExpanded: true,
                        decoration: InputDecoration(
                          hintText: 'All Statuses',
                          hintStyle: TextStyle(color: textSecondary),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                        ),
                        dropdownColor: surfaceColor,
                        items: const [
                          DropdownMenuItem(value: null, child: Text('All')),
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
                          setModalState(() => localSelectedStatus = value);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Category Filter
                      Text(
                        'Category',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: localSelectedCategory,
                        isExpanded: true,
                        decoration: InputDecoration(
                          hintText: 'All Categories',
                          hintStyle: TextStyle(color: textSecondary),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                        ),
                        dropdownColor: surfaceColor,
                        items: const [
                          DropdownMenuItem(value: null, child: Text('All')),
                          DropdownMenuItem(value: 'hot', child: Text('Hot')),
                          DropdownMenuItem(value: 'warm', child: Text('Warm')),
                          DropdownMenuItem(value: 'cold', child: Text('Cold')),
                        ],
                        onChanged: (value) {
                          setModalState(() => localSelectedCategory = value);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Company Filter
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
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: SearchableDropdown<Company>(
                          items: companiesState.companies,
                          value: localSelectedCompanyId != null
                              ? companiesState.companies
                                    .where(
                                      (c) => c.id == localSelectedCompanyId,
                                    )
                                    .firstOrNull
                              : null,
                          hintText: 'All Companies',
                          labelText: 'Company',
                          dropdownColor: surfaceColor,
                          textColor: textPrimary,
                          hintColor: textSecondary,
                          itemLabelBuilder: (company) => company.name,
                          onChanged: (company) {
                            setModalState(
                              () => localSelectedCompanyId = company?.id,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Revenue Range Filter
                      Text(
                        'Revenue Range',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: localSelectedRevenueRange,
                        isExpanded: true,
                        decoration: InputDecoration(
                          hintText: 'All Ranges',
                          hintStyle: TextStyle(color: textSecondary),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                        ),
                        dropdownColor: surfaceColor,
                        items: const [
                          DropdownMenuItem(value: null, child: Text('All')),
                          DropdownMenuItem(
                            value: '0-1000',
                            child: Text('\$0 - \$1K'),
                          ),
                          DropdownMenuItem(
                            value: '1000-5000',
                            child: Text('\$1K - \$5K'),
                          ),
                          DropdownMenuItem(
                            value: '5000-10000',
                            child: Text('\$5K - \$10K'),
                          ),
                          DropdownMenuItem(
                            value: '10000+',
                            child: Text('\$10K+'),
                          ),
                        ],
                        onChanged: (value) {
                          setModalState(
                            () => localSelectedRevenueRange = value,
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // KAM Filter
                      Text(
                        'Key Account Manager (KAM)',
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
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: SearchableDropdown<User>(
                          items: usersState.users,
                          value: localSelectedKamUserId != null
                              ? usersState.users
                                    .where(
                                      (u) => u.id == localSelectedKamUserId,
                                    )
                                    .firstOrNull
                              : null,
                          hintText: 'All KAMs',
                          labelText: 'Key Account Manager (KAM)',
                          dropdownColor: surfaceColor,
                          textColor: textPrimary,
                          hintColor: textSecondary,
                          itemLabelBuilder: (user) =>
                              '${user.name} (${user.email})',
                          onChanged: (user) {
                            setModalState(
                              () => localSelectedKamUserId = user?.id,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Date Range Filter
                      Text(
                        'Date Range (Closing Date)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: localStartDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (date != null) {
                                  setModalState(() => localStartDate = date);
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  hintText: 'Start Date',
                                  hintStyle: TextStyle(color: textSecondary),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: borderColor),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: borderColor),
                                  ),
                                ),
                                child: Text(
                                  localStartDate != null
                                      ? '${localStartDate!.day}/${localStartDate!.month}/${localStartDate!.year}'
                                      : 'Start Date',
                                  style: TextStyle(color: textPrimary),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: localEndDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (date != null) {
                                  setModalState(() => localEndDate = date);
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  hintText: 'End Date',
                                  hintStyle: TextStyle(color: textSecondary),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: borderColor),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: borderColor),
                                  ),
                                ),
                                child: Text(
                                  localEndDate != null
                                      ? '${localEndDate!.day}/${localEndDate!.month}/${localEndDate!.year}'
                                      : 'End Date',
                                  style: TextStyle(color: textPrimary),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _selectedStatus = null;
                                  _selectedCategory = null;
                                  _selectedCompanyId = null;
                                  _selectedRevenueRange = null;
                                  _selectedKamUserId = null;
                                  _startDate = null;
                                  _endDate = null;
                                  _sortBy = 'createdAt';
                                  _sortAscending = false;
                                });
                                ref.read(salesProvider.notifier).clearFilters();
                                Navigator.pop(context);
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: textPrimary,
                                side: BorderSide(color: borderColor),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Clear All'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _selectedStatus = localSelectedStatus;
                                  _selectedCategory = localSelectedCategory;
                                  _selectedCompanyId = localSelectedCompanyId;
                                  _selectedRevenueRange =
                                      localSelectedRevenueRange;
                                  _selectedKamUserId = localSelectedKamUserId;
                                  _startDate = localStartDate;
                                  _endDate = localEndDate;
                                  _sortBy = localSortBy;
                                  _sortAscending = localSortAscending;
                                });
                                ref
                                    .read(salesProvider.notifier)
                                    .setStatusFilter(localSelectedStatus);
                                ref
                                    .read(salesProvider.notifier)
                                    .setCategoryFilter(localSelectedCategory);
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor:
                                    Theme.of(context).colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Apply Filters'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
