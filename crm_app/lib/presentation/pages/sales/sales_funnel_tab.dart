import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/async_load_helper.dart';
import '../../../data/models/company_model.dart';
import '../../../data/models/sale_model.dart';
import '../../../data/models/status_config_model.dart';
import '../../../data/models/user_model.dart';
import '../../../core/constants/rbac_page_keys.dart';
import '../../providers/sale_provider.dart';
import '../../providers/company_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/status_config_provider.dart';
import '../../providers/rbac_provider.dart'
    show rbacAccessDigestProvider, rbacModuleAdminProvider;
import '../../widgets/crm_card.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/list_page_state.dart';
import '../../widgets/searchable_dropdown.dart';
import '../../widgets/app_search_filter_bar.dart';
import 'sale_detail_page.dart';

/// Avoid hundreds of tabs / Wrap chips if the API returns a huge status list.
const int _kMaxDealPipelineStages = 24;

List<String> _normalizeDealPipeline(List<String> raw) {
  final capped = raw.length > _kMaxDealPipelineStages
      ? raw.take(_kMaxDealPipelineStages).toList()
      : List<String>.from(raw);
  if (capped.isEmpty) {
    capped.addAll(List<String>.from(StatusConfig.defaultDealPipelineStatuses));
  }
  return capped;
}

/// Pipeline + list for the **Sales** segment inside [DealsPage].
class SalesFunnelTab extends ConsumerStatefulWidget {
  const SalesFunnelTab({super.key});

  @override
  ConsumerState<SalesFunnelTab> createState() => _SalesFunnelTabState();
}

class _SalesFunnelTabState extends ConsumerState<SalesFunnelTab>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<String> _pipelineStatuses =
      List<String>.from(StatusConfig.defaultDealPipelineStatuses);

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
    _tabController = TabController(
      length: _pipelineStatuses.length + 1,
      vsync: this,
    );
    _tabController.addListener(_onTabIndexChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(salesProvider.notifier).loadSales();
      ref.read(companiesProvider.notifier).loadCompanies();
      ref.read(usersProvider.notifier).loadUsers();
    });
  }

  void _applyTabIndexToProvider() {
    if (!mounted) return;
    final idx = _tabController.index;
    final status =
        idx < _pipelineStatuses.length ? _pipelineStatuses[idx] : null;
    ref.read(salesProvider.notifier).setStatusFilter(status);
    if (_selectedStatus != status) {
      setState(() => _selectedStatus = status);
    }
  }

  void _onTabIndexChanged() {
    if (_tabController.indexIsChanging) return;
    _applyTabIndexToProvider();
  }

  bool _samePipeline(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabController.removeListener(_onTabIndexChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<StatusConfig>>(statusConfigProvider, (prev, next) {
      next.whenData((cfg) {
        final source = cfg.salesStatuses.isNotEmpty
            ? cfg.salesStatuses
            : StatusConfig.defaultDealPipelineStatuses;
        final list = _normalizeDealPipeline(List<String>.from(source));
        if (_samePipeline(list, _pipelineStatuses)) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_samePipeline(list, _pipelineStatuses)) return;
          // Keep tab index + controller length + _pipelineStatuses in sync.
          final savedIndex =
              _tabController.index.clamp(0, _pipelineStatuses.length);
          _tabController.removeListener(_onTabIndexChanged);
          _tabController.dispose();
          _tabController = TabController(
            length: list.length + 1,
            vsync: this,
            initialIndex: savedIndex.clamp(0, list.length),
          );
          _tabController.addListener(_onTabIndexChanged);
          setState(() => _pipelineStatuses = list);
          _applyTabIndexToProvider();
        });
      });
    });

    ref.watch(rbacAccessDigestProvider);
    ref.watch(rbacModuleAdminProvider(RbacPageKey.sales));
    ref.watch(statusConfigProvider);
    final salesState = ref.watch(salesProvider);

    ref.listen<SalesState>(salesProvider, (prev, next) {
      if (next.error != null &&
          prev?.error != next.error &&
          next.sales.isNotEmpty &&
          context.mounted) {
        showRefreshErrorSnackBar(context, next.error!);
      }
    });

    final companiesState = ref.watch(companiesProvider);
    final usersState = ref.watch(usersProvider);
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
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

    // Search + pipeline TabBar stay here (not in parent AppBar) to avoid overflow.
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSearchFilterBar(
            controller: _searchController,
            hintText: 'Search deals...',
            activeFilterCount: activeFilterCount,
            onChanged: (value) {
              _searchDebounce?.cancel();
              _searchDebounce = Timer(const Duration(milliseconds: 450), () {
                ref.read(salesProvider.notifier).setListSearchAndReload(value);
              });
              setState(() {});
            },
            onClear: () {
              _searchDebounce?.cancel();
              _searchController.clear();
              ref.read(salesProvider.notifier).setListSearchAndReload(null);
              setState(() {});
            },
            onFilterTap: () => _showFilterSheet(
              context,
              companiesState,
              usersState,
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
          Material(
            color: surfaceColor,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
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
              tabs: [
                ..._pipelineStatuses.map(
                  (s) => Tab(text: _dealTabLabel(s)),
                ),
                const Tab(text: 'All'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                ..._pipelineStatuses.map((s) => _buildSalesList(salesState, s)),
                _buildSalesList(salesState, null),
              ],
            ),
          ),
        ],
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

    // Always copy: provider may hold an unmodifiable list; we sort in place below.
    var sales = List<Sale>.from(state.sales);
    if (status != null) {
      sales = sales.where((s) => s.status == status).toList();
    }

    // Search is applied server-side via GET /api/sales?search=

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

    return AsyncScreenView(
      isLoading: state.isLoading && state.sales.isEmpty,
      isRefreshing: state.isRefreshing,
      hasCachedData: state.sales.isNotEmpty,
      error: state.error,
      isEmpty: sales.isEmpty,
      onRetry: () => ref.read(salesProvider.notifier).loadSales(),
      emptyTitle: 'No deals found',
      emptySubtitle: status != null
          ? 'No ${status.replaceAll('_', ' ')} deals yet'
          : 'Create your first deal',
      emptyIcon: Icons.trending_up,
      emptyButtonText: 'Add Deal',
      onEmptyAction: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SaleFormPage()),
        );
      },
      content: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(statusConfigProvider);
          await ref.read(salesProvider.notifier).loadSales(refresh: true);
        },
        child: FadeInContent(
          child: ListView.builder(
            padding: AppThemeColors.pagePaddingAll,
            physics: const AlwaysScrollableScrollPhysics(),
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
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _dealTabLabel(String status) {
    if (status.isEmpty) return '—';
    switch (status) {
      case 'closed_won':
        return 'Closed Won';
      case 'closed_lost':
        return 'Closed Lost';
      case 'in_progress':
        return 'In Progress';
      default:
        final t = status.replaceAll('_', ' ');
        if (t.isEmpty) return '—';
        return t[0].toUpperCase() + t.substring(1);
    }
  }

  void _showFilterSheet(
    BuildContext context,
    CompaniesState companiesState,
    UsersState usersState,
  ) {
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final borderColor = AppThemeColors.borderColor(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    String? localSelectedStatus = _selectedStatus;
    String? localSelectedCategory = _selectedCategory;
    String? localSelectedCompanyId = _selectedCompanyId;
    String? localSelectedRevenueRange = _selectedRevenueRange;
    String? localSelectedKamUserId = _selectedKamUserId;
    String localSortBy = _sortBy;
    bool localSortAscending = _sortAscending;
    DateTime? localStartDate = _startDate;
    DateTime? localEndDate = _endDate;

    InputBorder fieldBorder() => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) => SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.md,
              top: AppSpacing.md,
              bottom:
                  AppSpacing.md + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        _searchDebounce?.cancel();
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
                        _searchController.clear();
                        ref.read(salesProvider.notifier).clearFilters();
                        await ref
                            .read(salesProvider.notifier)
                            .clearListApiFiltersAndReload();
                        if (sheetContext.mounted) {
                          Navigator.pop(sheetContext);
                        }
                      },
                      child: Text(
                        'Clear All',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.md),
                Text(
                  'Sort by',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                DropdownButtonFormField<String>(
                  initialValue: localSortBy,
                  isExpanded: true,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: fieldBorder(),
                    enabledBorder: fieldBorder(),
                  ),
                  dropdownColor: surfaceColor,
                  items: const [
                    DropdownMenuItem(
                      value: 'createdAt',
                      child: Text('Date created'),
                    ),
                    DropdownMenuItem(
                      value: 'expectedClosingDate',
                      child: Text('Closing date'),
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
                SizedBox(height: AppSpacing.md),
                Text(
                  'Status',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                DropdownButtonFormField<String>(
                  initialValue: localSelectedStatus,
                  isExpanded: true,
                  decoration: InputDecoration(
                    hintText: 'All statuses',
                    hintStyle: TextStyle(color: textSecondary),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: fieldBorder(),
                    enabledBorder: fieldBorder(),
                  ),
                  dropdownColor: surfaceColor,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    ..._pipelineStatuses.map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(_dealTabLabel(s)),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setModalState(() => localSelectedStatus = value);
                  },
                ),
                SizedBox(height: AppSpacing.md),
                Text(
                  'Category',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                DropdownButtonFormField<String>(
                  initialValue: localSelectedCategory,
                  isExpanded: true,
                  decoration: InputDecoration(
                    hintText: 'All categories',
                    hintStyle: TextStyle(color: textSecondary),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: fieldBorder(),
                    enabledBorder: fieldBorder(),
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
                SizedBox(height: AppSpacing.md),
                Text(
                  'Company',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                Container(
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: SearchableDropdown<Company>(
                    items: companiesState.companies,
                    value: localSelectedCompanyId != null
                        ? companiesState.companies
                            .where((c) => c.id == localSelectedCompanyId)
                            .firstOrNull
                        : null,
                    hintText: 'All companies',
                    labelText: '',
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
                SizedBox(height: AppSpacing.md),
                Text(
                  'Revenue range',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                DropdownButtonFormField<String>(
                  initialValue: localSelectedRevenueRange,
                  isExpanded: true,
                  decoration: InputDecoration(
                    hintText: 'All ranges',
                    hintStyle: TextStyle(color: textSecondary),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: fieldBorder(),
                    enabledBorder: fieldBorder(),
                  ),
                  dropdownColor: surfaceColor,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    DropdownMenuItem(
                      value: '0-1000',
                      child: Text(
                        '${AppConstants.currencySymbol}0 - '
                        '${AppConstants.currencySymbol}1K',
                      ),
                    ),
                    DropdownMenuItem(
                      value: '1000-5000',
                      child: Text(
                        '${AppConstants.currencySymbol}1K - '
                        '${AppConstants.currencySymbol}5K',
                      ),
                    ),
                    DropdownMenuItem(
                      value: '5000-10000',
                      child: Text(
                        '${AppConstants.currencySymbol}5K - '
                        '${AppConstants.currencySymbol}10K',
                      ),
                    ),
                    DropdownMenuItem(
                      value: '10000+',
                      child: Text('${AppConstants.currencySymbol}10K+'),
                    ),
                  ],
                  onChanged: (value) {
                    setModalState(() => localSelectedRevenueRange = value);
                  },
                ),
                SizedBox(height: AppSpacing.md),
                Text(
                  'KAM',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                Container(
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: SearchableDropdown<User>(
                    items: usersState.users,
                    value: localSelectedKamUserId != null
                        ? usersState.users
                            .where((u) => u.id == localSelectedKamUserId)
                            .firstOrNull
                        : null,
                    hintText: 'Search by name or email...',
                    labelText: '',
                    dropdownColor: surfaceColor,
                    textColor: textPrimary,
                    hintColor: textSecondary,
                    itemLabelBuilder: (user) =>
                        '${user.name} (${user.email})',
                    onChanged: (user) {
                      setModalState(() => localSelectedKamUserId = user?.id);
                    },
                  ),
                ),
                SizedBox(height: AppSpacing.md),
                Text(
                  'Closing date',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: _salesFunnelDateFilterButton(
                        context: context,
                        label: 'From',
                        date: localStartDate,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        borderColor: borderColor,
                        surfaceColor: surfaceColor,
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: localStartDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (date != null) {
                            setModalState(() => localStartDate = date);
                          }
                        },
                        onClear: () =>
                            setModalState(() => localStartDate = null),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _salesFunnelDateFilterButton(
                        context: context,
                        label: 'To',
                        date: localEndDate,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        borderColor: borderColor,
                        surfaceColor: surfaceColor,
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: localEndDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (date != null) {
                            setModalState(() => localEndDate = date);
                          }
                        },
                        onClear: () => setModalState(() => localEndDate = null),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      setState(() {
                        _selectedStatus = localSelectedStatus;
                        _selectedCategory = localSelectedCategory;
                        _selectedCompanyId = localSelectedCompanyId;
                        _selectedRevenueRange = localSelectedRevenueRange;
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

                      final allIdx = _pipelineStatuses.length;
                      final st = localSelectedStatus;
                      final tabIdx =
                          st == null ? allIdx : _pipelineStatuses.indexOf(st);
                      final safeIdx = (tabIdx >= 0 ? tabIdx : allIdx)
                          .clamp(0, _tabController.length - 1);
                      if (_tabController.index != safeIdx) {
                        _tabController.animateTo(safeIdx);
                      }

                      await ref
                          .read(salesProvider.notifier)
                          .setListCompanyCategoryAndReload(
                            companyId: localSelectedCompanyId,
                            category: localSelectedCategory,
                          );
                      if (sheetContext.mounted) {
                        Navigator.pop(sheetContext);
                      }
                    },
                    child: const Text('Apply Filters'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _salesFunnelDateFilterButton({
  required BuildContext context,
  required String label,
  required DateTime? date,
  required Color textPrimary,
  required Color textSecondary,
  required Color borderColor,
  required Color surfaceColor,
  required VoidCallback onTap,
  required VoidCallback onClear,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today, size: 18, color: textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              date != null ? '${date.day}/${date.month}/${date.year}' : label,
              style: TextStyle(
                color: date != null ? textPrimary : textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          if (date != null)
            GestureDetector(
              onTap: onClear,
              child: Icon(Icons.close, size: 18, color: textSecondary),
            )
          else
            Icon(Icons.arrow_drop_down, color: textSecondary),
        ],
      ),
    ),
  );
}
