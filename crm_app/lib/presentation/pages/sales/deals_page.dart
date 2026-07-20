import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/async_load_helper.dart';
import '../../../data/models/company_model.dart';
import '../../../data/models/order_model.dart';
import '../../../data/models/renewal_model.dart';
import '../../../data/models/user_model.dart';
import '../../providers/company_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/renewal_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/app_search_filter_bar.dart';
import '../../widgets/searchable_dropdown.dart';
import '../../widgets/crm_card.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/list_page_state.dart';
import '../../widgets/status_badge.dart';
import 'order_detail_page.dart';
import 'order_form_page.dart';
import 'renewal_form_page.dart';
import 'sale_detail_page.dart';
import 'sales_funnel_tab.dart';

/// Deals hub: **Sales** funnel, **Orders**, and **Renewals** (see Postman Orders / Renewals).
class DealsPage extends ConsumerStatefulWidget {
  const DealsPage({super.key});

  @override
  ConsumerState<DealsPage> createState() => _DealsPageState();
}

class _DealsPageState extends ConsumerState<DealsPage>
    with SingleTickerProviderStateMixin {
  late TabController _hubController;
  final TextEditingController _ordersSearchController =
      TextEditingController();
  final TextEditingController _renewalsSearchController =
      TextEditingController();
  Timer? _ordersDebounce;
  Timer? _renewalsDebounce;

  @override
  void initState() {
    super.initState();
    _hubController = TabController(length: 3, vsync: this);
    _hubController.addListener(_onHubChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(usersProvider.notifier).loadUsers();
      ref.read(companiesProvider.notifier).loadCompanies();
    });
  }

  void _onHubChanged() {
    if (_hubController.indexIsChanging) return;
    setState(() {});
  }

  @override
  void dispose() {
    _hubController.removeListener(_onHubChanged);
    _hubController.dispose();
    _ordersDebounce?.cancel();
    _renewalsDebounce?.cancel();
    _ordersSearchController.dispose();
    _renewalsSearchController.dispose();
    super.dispose();
  }

  void _openFab() {
    switch (_hubController.index) {
      case 0:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SaleFormPage()),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const RenewalFormPage()),
        ).then((created) {
          if (created == true && mounted) {
            ref.read(renewalsProvider.notifier).loadRenewals();
          }
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = AppThemeColors.backgroundColor(context);
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final ordersState = ref.watch(ordersProvider);
    final renewalsState = ref.watch(renewalsProvider);

    ref.listen<OrdersState>(ordersProvider, (prev, next) {
      if (next.error != null &&
          prev?.error != next.error &&
          next.orders.isNotEmpty &&
          context.mounted) {
        showRefreshErrorSnackBar(context, next.error!);
      }
    });

    ref.listen<RenewalsState>(renewalsProvider, (prev, next) {
      if (next.error != null &&
          prev?.error != next.error &&
          next.renewals.isNotEmpty &&
          context.mounted) {
        showRefreshErrorSnackBar(context, next.error!);
      }
    });

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppThemeColors.appBarTitle(context, 'Deals'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: surfaceColor,
            child: TabBar(
              controller: _hubController,
              labelColor: primaryColor,
              unselectedLabelColor: textSecondary,
              indicatorColor: primaryColor,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Funnel'),
                Tab(text: 'Orders'),
                Tab(text: 'Renewals'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _hubController,
              children: [
                const SalesFunnelTab(),
                _OrdersPane(
                  ordersState: ordersState,
                  searchController: _ordersSearchController,
                  activeFilterCount: ordersState.listFilters.activeCount,
                  onSearchChanged: (v) {
                    setState(() {});
                    _ordersDebounce?.cancel();
                    _ordersDebounce = Timer(
                      const Duration(milliseconds: 400),
                      () {
                        ref.read(ordersProvider.notifier).setListSearch(v);
                        setState(() {});
                      },
                    );
                  },
                  onSearchClear: () {
                    _ordersDebounce?.cancel();
                    _ordersSearchController.clear();
                    ref.read(ordersProvider.notifier).setListSearch(null);
                    setState(() {});
                  },
                  onFilterTap: () => _showOrdersFilterSheet(context),
                  onRefresh: () =>
                      ref.read(ordersProvider.notifier).loadOrders(refresh: true),
                  onOpenDetail: (id) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OrderDetailPage(orderId: id),
                      ),
                    ).then((_) {
                      ref.read(ordersProvider.notifier).loadOrders();
                    });
                  },
                ),
                _RenewalsPane(
                  renewalsState: renewalsState,
                  searchController: _renewalsSearchController,
                  activeFilterCount: renewalsState.listFilters.activeCount,
                  onSearchChanged: (v) {
                    setState(() {});
                    _renewalsDebounce?.cancel();
                    _renewalsDebounce = Timer(
                      const Duration(milliseconds: 450),
                      () {
                        ref
                            .read(renewalsProvider.notifier)
                            .setListSearchAndReload(v);
                      },
                    );
                  },
                  onSearchClear: () {
                    _renewalsDebounce?.cancel();
                    _renewalsSearchController.clear();
                    ref
                        .read(renewalsProvider.notifier)
                        .setListSearchAndReload(null);
                  },
                  onFilterTap: () => _showRenewalsFilterSheet(context),
                  onRefresh: () => ref
                      .read(renewalsProvider.notifier)
                      .loadRenewals(refresh: true),
                  onOpenRenewal: (renewal) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            RenewalFormPage(renewal: renewal),
                      ),
                    ).then((_) {
                      ref.read(renewalsProvider.notifier).loadRenewals();
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _hubController.index == 1
          ? null
          : FloatingActionButton(
              onPressed: _openFab,
              child: const Icon(Icons.add),
            ),
    );
  }

  void _showOrdersFilterSheet(BuildContext context) {
    final ordersState = ref.read(ordersProvider);
    final usersState = ref.read(usersProvider);
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final borderColor = AppThemeColors.borderColor(context);
    final f = ordersState.listFilters;

    var statusOptions = ordersState.orders
        .map((o) => o.status)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
    final curStatus = f.status;
    if (curStatus != null &&
        curStatus.trim().isNotEmpty &&
        !statusOptions.contains(curStatus)) {
      statusOptions = [...statusOptions, curStatus]..sort();
    }

    String? selectedStatus = f.status;
    String? selectedAssigneeId = f.assignToUserId;
    DateTime? deliveryFrom = f.deliveryFrom;
    DateTime? deliveryTo = f.deliveryTo;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.md,
              top: AppSpacing.md,
              bottom: AppSpacing.md + MediaQuery.of(context).viewInsets.bottom,
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
                      onTap: () {
                        ref.read(ordersProvider.notifier).clearListFilters();
                        Navigator.pop(context);
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
                  'Status',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  isExpanded: true,
                  decoration: InputDecoration(
                    hintText: 'All statuses',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                  dropdownColor: surfaceColor,
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All'),
                    ),
                    ...statusOptions.map(
                      (s) => DropdownMenuItem(value: s, child: Text(s)),
                    ),
                  ],
                  onChanged: (v) => setModalState(() => selectedStatus = v),
                ),
                SizedBox(height: AppSpacing.md),
                Text(
                  'Assigned to',
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
                    value: selectedAssigneeId != null
                        ? usersState.users
                            .where((u) => u.id == selectedAssigneeId)
                            .firstOrNull
                        : null,
                    hintText: 'Search by name or email...',
                    labelText: '',
                    dropdownColor: surfaceColor,
                    textColor: textPrimary,
                    hintColor: textSecondary,
                    itemLabelBuilder: (user) => '${user.name} (${user.email})',
                    onChanged: (user) {
                      setModalState(() => selectedAssigneeId = user?.id);
                    },
                  ),
                ),
                SizedBox(height: AppSpacing.md),
                Text(
                  'Delivery date',
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
                      child: _dealsDateFilterButton(
                        context: context,
                        label: 'From',
                        date: deliveryFrom,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        borderColor: borderColor,
                        surfaceColor: surfaceColor,
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: deliveryFrom ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (date != null) {
                            setModalState(() => deliveryFrom = date);
                          }
                        },
                        onClear: () => setModalState(() => deliveryFrom = null),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _dealsDateFilterButton(
                        context: context,
                        label: 'To',
                        date: deliveryTo,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        borderColor: borderColor,
                        surfaceColor: surfaceColor,
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: deliveryTo ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (date != null) {
                            setModalState(() => deliveryTo = date);
                          }
                        },
                        onClear: () => setModalState(() => deliveryTo = null),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      ref.read(ordersProvider.notifier).setListFilters(
                            OrderListFilters(
                              status: selectedStatus,
                              assignToUserId: selectedAssigneeId,
                              deliveryFrom: deliveryFrom,
                              deliveryTo: deliveryTo,
                            ),
                          );
                      Navigator.pop(context);
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

  void _showRenewalsFilterSheet(BuildContext context) {
    final renewalsState = ref.read(renewalsProvider);
    final companiesState = ref.read(companiesProvider);
    final usersState = ref.read(usersProvider);
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final borderColor = AppThemeColors.borderColor(context);
    final f = renewalsState.listFilters;

    var sourceOptions = renewalsState.renewals
        .map((r) => r.source)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
    final curSource = f.source;
    if (curSource != null &&
        curSource.trim().isNotEmpty &&
        !sourceOptions.contains(curSource)) {
      sourceOptions = [...sourceOptions, curSource]..sort();
    }

    String? selectedCompanyId = f.companyId;
    String? selectedKamId = f.kamUserId;
    String? selectedSource = f.source;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.md,
              top: AppSpacing.md,
              bottom: AppSpacing.md + MediaQuery.of(context).viewInsets.bottom,
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
                        await ref
                            .read(renewalsProvider.notifier)
                            .clearListFiltersAndReload();
                        if (context.mounted) Navigator.pop(context);
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
                    value: selectedCompanyId != null
                        ? companiesState.companies
                            .where((c) => c.id == selectedCompanyId)
                            .firstOrNull
                        : null,
                    hintText: 'All companies',
                    labelText: '',
                    dropdownColor: surfaceColor,
                    textColor: textPrimary,
                    hintColor: textSecondary,
                    itemLabelBuilder: (c) => c.name,
                    onChanged: (c) {
                      setModalState(() => selectedCompanyId = c?.id);
                    },
                  ),
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
                    value: selectedKamId != null
                        ? usersState.users
                            .where((u) => u.id == selectedKamId)
                            .firstOrNull
                        : null,
                    hintText: 'Search by name or email...',
                    labelText: '',
                    dropdownColor: surfaceColor,
                    textColor: textPrimary,
                    hintColor: textSecondary,
                    itemLabelBuilder: (user) => '${user.name} (${user.email})',
                    onChanged: (user) {
                      setModalState(() => selectedKamId = user?.id);
                    },
                  ),
                ),
                SizedBox(height: AppSpacing.md),
                Text(
                  'Source',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                DropdownButtonFormField<String>(
                  initialValue: selectedSource,
                  isExpanded: true,
                  decoration: InputDecoration(
                    hintText: 'All sources',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                  dropdownColor: surfaceColor,
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All'),
                    ),
                    ...sourceOptions.map(
                      (s) => DropdownMenuItem(value: s, child: Text(s)),
                    ),
                  ],
                  onChanged: (v) => setModalState(() => selectedSource = v),
                ),
                SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      await ref
                          .read(renewalsProvider.notifier)
                          .setListFiltersAndReload(
                            RenewalListFilters(
                              companyId: selectedCompanyId,
                              kamUserId: selectedKamId,
                              source: selectedSource,
                            ),
                          );
                      if (context.mounted) Navigator.pop(context);
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

Widget _dealsDateFilterButton({
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

class _OrdersPane extends ConsumerWidget {
  final OrdersState ordersState;
  final TextEditingController searchController;
  final int activeFilterCount;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchClear;
  final VoidCallback onFilterTap;
  final Future<void> Function() onRefresh;
  final void Function(String id) onOpenDetail;

  const _OrdersPane({
    required this.ordersState,
    required this.searchController,
    required this.activeFilterCount,
    required this.onSearchChanged,
    required this.onSearchClear,
    required this.onFilterTap,
    required this.onRefresh,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final textTertiary = AppThemeColors.textTertiaryColor(context);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final rows = ordersState.visibleOrders;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSearchFilterBar(
          controller: searchController,
          hintText: 'Search orders...',
          activeFilterCount: activeFilterCount,
          onChanged: onSearchChanged,
          onClear: onSearchClear,
          onFilterTap: onFilterTap,
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.45),
        ),
        Expanded(
          child: _ordersBody(
            context,
            ordersState,
            rows,
            textPrimary,
            textSecondary,
            textTertiary,
            primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _ordersBody(
    BuildContext context,
    OrdersState state,
    List<Order> rows,
    Color textPrimary,
    Color textSecondary,
    Color textTertiary,
    Color primaryColor,
  ) {
    return AsyncScreenView(
      isLoading: state.isLoading,
      isRefreshing: state.isRefreshing,
      hasCachedData: state.orders.isNotEmpty,
      error: state.error,
      isEmpty: rows.isEmpty,
      onRetry: () => onRefresh(),
      emptyTitle: 'No orders',
      emptySubtitle: 'Create an order from a deal or here',
      emptyIcon: Icons.shopping_cart_outlined,
      emptyButtonText: 'Add order',
      onEmptyAction: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const OrderFormPage()),
        ).then((created) {
          if (created == true) onRefresh();
        });
      },
      content: RefreshIndicator(
        onRefresh: onRefresh,
        child: FadeInContent(
          child: ListView.builder(
            padding: AppThemeColors.listPagePadding,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final o = rows[index];
              return Padding(
                padding: AppThemeColors.cardListItemMargin,
                child: CRMCard(
                  onTap: () => onOpenDetail(o.id),
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
                                  o.company?.name ?? 'Order',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  o.orderDetails ?? '—',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            o.formattedRevenue,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (o.status != null)
                            StatusBadge(status: o.status!, type: 'sale')
                          else
                            const SizedBox.shrink(),
                          const Spacer(),
                          if (o.deliveryDate != null)
                            Text(
                              'Delivery: ${_fmt(o.deliveryDate!)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: textTertiary,
                              ),
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

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

class _RenewalsPane extends ConsumerWidget {
  final RenewalsState renewalsState;
  final TextEditingController searchController;
  final int activeFilterCount;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchClear;
  final VoidCallback onFilterTap;
  final Future<void> Function() onRefresh;
  final void Function(Renewal renewal) onOpenRenewal;

  const _RenewalsPane({
    required this.renewalsState,
    required this.searchController,
    required this.activeFilterCount,
    required this.onSearchChanged,
    required this.onSearchClear,
    required this.onFilterTap,
    required this.onRefresh,
    required this.onOpenRenewal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final rows = renewalsState.renewals;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSearchFilterBar(
          controller: searchController,
          hintText: 'Search renewals...',
          activeFilterCount: activeFilterCount,
          onChanged: onSearchChanged,
          onClear: onSearchClear,
          onFilterTap: onFilterTap,
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.45),
        ),
        Expanded(
          child: _renewalsBody(
            context,
            renewalsState,
            rows,
            textPrimary,
            textSecondary,
            primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _renewalsBody(
    BuildContext context,
    RenewalsState state,
    List<Renewal> rows,
    Color textPrimary,
    Color textSecondary,
    Color primaryColor,
  ) {
    return AsyncScreenView(
      isLoading: state.isLoading,
      isRefreshing: state.isRefreshing,
      hasCachedData: state.renewals.isNotEmpty,
      error: state.error,
      isEmpty: rows.isEmpty,
      onRetry: () => onRefresh(),
      emptyTitle: 'No renewals',
      emptySubtitle: 'Track contract renewals here',
      emptyIcon: Icons.autorenew,
      emptyButtonText: 'Add renewal',
      onEmptyAction: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const RenewalFormPage()),
        ).then((created) {
          if (created == true) onRefresh();
        });
      },
      content: RefreshIndicator(
        onRefresh: onRefresh,
        child: FadeInContent(
          child: ListView.builder(
            padding: AppThemeColors.listPagePadding,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final r = rows[index];
              return Padding(
                padding: AppThemeColors.cardListItemMargin,
                child: CRMCard(
                  onTap: () => onOpenRenewal(r),
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
                                  r.company?.name ?? 'Renewal',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  r.productDetails ?? '—',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (r.renewalType != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                r.renewalType!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      if (r.renewalDate != null)
                        Text(
                          'Renewal: ${_fmt(r.renewalDate!)}',
                          style: TextStyle(fontSize: 12, color: textSecondary),
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

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
}
