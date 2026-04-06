import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme_colors.dart';
import '../../../data/models/order_model.dart';
import '../../../data/models/renewal_model.dart';
import '../../providers/order_provider.dart';
import '../../providers/renewal_provider.dart';
import '../../widgets/app_search_filter_bar.dart';
import '../../widgets/crm_card.dart';
import '../../widgets/error_widget.dart' as app_widgets;
import '../../widgets/loading_widget.dart';
import '../../widgets/status_badge.dart';
import 'order_detail_page.dart';
import 'order_form_page.dart';
import 'renewal_detail_page.dart';
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
                  onRefresh: () =>
                      ref.read(ordersProvider.notifier).loadOrders(),
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
                  onRefresh: () =>
                      ref.read(renewalsProvider.notifier).loadRenewals(),
                  onOpenDetail: (id) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            RenewalDetailPage(renewalId: id),
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
}

class _OrdersPane extends StatelessWidget {
  final OrdersState ordersState;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchClear;
  final Future<void> Function() onRefresh;
  final void Function(String id) onOpenDetail;

  const _OrdersPane({
    required this.ordersState,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSearchClear,
    required this.onRefresh,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
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
          activeFilterCount: 0,
          onChanged: onSearchChanged,
          onClear: onSearchClear,
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
    if (state.isLoading && state.orders.isEmpty) {
      return const LoadingWidget();
    }
    if (state.error != null && state.orders.isEmpty) {
      return app_widgets.ErrorWidget(
        message: state.error!,
        onRetry: onRefresh,
      );
    }
    if (rows.isEmpty) {
      return app_widgets.EmptyStateWidget(
        title: 'No orders',
        subtitle: 'Create an order from a deal or here',
        icon: Icons.shopping_cart_outlined,
        buttonText: 'Add order',
        onButtonPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const OrderFormPage()),
          ).then((created) {
            if (created == true) onRefresh();
          });
        },
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: AppThemeColors.pagePaddingAll,
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final o = rows[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
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
    );
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

class _RenewalsPane extends StatelessWidget {
  final RenewalsState renewalsState;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchClear;
  final Future<void> Function() onRefresh;
  final void Function(String id) onOpenDetail;

  const _RenewalsPane({
    required this.renewalsState,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSearchClear,
    required this.onRefresh,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
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
          activeFilterCount: 0,
          onChanged: onSearchChanged,
          onClear: onSearchClear,
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
    if (state.isLoading && state.renewals.isEmpty) {
      return const LoadingWidget();
    }
    if (state.error != null && state.renewals.isEmpty) {
      return app_widgets.ErrorWidget(
        message: state.error!,
        onRetry: onRefresh,
      );
    }
    if (rows.isEmpty) {
      return app_widgets.EmptyStateWidget(
        title: 'No renewals',
        subtitle: 'Track contract renewals here',
        icon: Icons.autorenew,
        buttonText: 'Add renewal',
        onButtonPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RenewalFormPage()),
          ).then((created) {
            if (created == true) onRefresh();
          });
        },
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: AppThemeColors.pagePaddingAll,
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final r = rows[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CRMCard(
              onTap: () => onOpenDetail(r.id),
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
                  const SizedBox(height: 8),
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
    );
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
}
