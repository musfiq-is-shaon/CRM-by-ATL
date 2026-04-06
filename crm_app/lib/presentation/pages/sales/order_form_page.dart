import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/sale_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/order_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/sale_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/crm_card.dart';
import '../../widgets/searchable_dropdown.dart';

String _formatOrderDateYmd(DateTime d) {
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Create [OrderFormPage] after a deal is **Closed Won**, or pick any Closed Won deal.
///
/// Orders require a linked Closed Won sale (`salesId`); there is no standalone order.
class OrderFormPage extends ConsumerStatefulWidget {
  /// When set, the deal is fixed and fields are prefilled from the funnel.
  final Sale? closedWonSale;

  const OrderFormPage({super.key, this.closedWonSale});

  @override
  ConsumerState<OrderFormPage> createState() => _OrderFormPageState();
}

class _OrderFormPageState extends ConsumerState<OrderFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _detailsController = TextEditingController();
  final _revenueController = TextEditingController();
  final _listScrollController = ScrollController();
  final _assignFieldKey = GlobalKey();

  String? _companyId;
  String? _saleId;
  Sale? _pickedSale;
  String? _assignToId;
  DateTime? _confirmed;
  DateTime? _delivery;
  bool _submitting = false;

  bool get _dealLocked => widget.closedWonSale != null;

  Sale? get _effectiveSale => widget.closedWonSale ?? _pickedSale;

  static bool _isClosedWon(Sale s) => s.status == 'closed_won';

  @override
  void initState() {
    super.initState();
    final fromDeal = widget.closedWonSale;
    if (fromDeal != null) {
      _applyPrefillFromSale(fromDeal);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(companiesProvider.notifier).loadCompanies();
      ref.read(usersProvider.notifier).loadUsers();
      ref.read(salesProvider.notifier).loadSales();
    });
  }

  void _applyPrefillFromSale(Sale s) {
    _companyId = s.companyId;
    _saleId = s.id;
    _pickedSale = _dealLocked ? null : s;

    final lines = <String>[s.prospect];
    if (s.nextAction != null && s.nextAction!.trim().isNotEmpty) {
      lines.add('Next action (from deal): ${s.nextAction}');
    }
    _detailsController.text = lines.join('\n');

    if (s.expectedRevenue != null) {
      final r = s.expectedRevenue!;
      _revenueController.text =
          r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toString();
    }

    _confirmed = DateTime.now();
    _delivery = s.expectedClosingDate ??
        DateTime.now().add(const Duration(days: 14));

    final kam = s.company?.kamUserId;
    final me = ref.read(authProvider).user?.id;
    _assignToId = (kam != null && kam.isNotEmpty) ? kam : me;
  }

  @override
  void dispose() {
    _listScrollController.dispose();
    _detailsController.dispose();
    _revenueController.dispose();
    super.dispose();
  }

  void _scrollAssignIntoView() {
    final ctx = _assignFieldKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.12,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _pickDate({
    required DateTime? current,
    required void Function(DateTime) onPick,
  }) async {
    final d = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (d != null) onPick(d);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final sale = _effectiveSale;
    if (sale == null || !_isClosedWon(sale)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Orders require a Closed Won deal. Select one or close a deal as Won first.',
          ),
        ),
      );
      return;
    }
    if (_companyId == null || _companyId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Company is missing for this deal')),
      );
      return;
    }
    if (_saleId == null || _saleId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Linked deal is required')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(orderRepositoryProvider).createOrder(
            companyId: _companyId!,
            salesId: _saleId,
            orderDetails: _detailsController.text.trim(),
            revenue: double.tryParse(_revenueController.text.trim()),
            orderConfirmationDate: _confirmed,
            deliveryDate: _delivery,
            assignTo: _assignToId,
            statusChangeNote: null,
            changedByUserId: ref.read(authProvider).user?.id,
            // API: sync linked funnel deal to Closed Won when the order is created (Postman).
            finalizeCloseWon: _saleId != null && _saleId!.isNotEmpty,
            closedWonStatus: 'closed_won',
          );
      if (mounted) {
        await ref.read(ordersProvider.notifier).loadOrders();
        await ref.read(salesProvider.notifier).loadSales();
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersState = ref.watch(usersProvider);
    final salesState = ref.watch(salesProvider);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final borderColor = AppThemeColors.borderColor(context);
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    final closedWonSales =
        salesState.sales.where(_isClosedWon).toList(growable: false);

    final viewInsets = MediaQuery.viewInsetsOf(context);
    final listPadding = AppThemeColors.pagePaddingAll.copyWith(
      bottom: AppThemeColors.pagePaddingAll.bottom + viewInsets.bottom + 32,
    );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppThemeColors.backgroundColor(context),
      appBar: AppThemeColors.appBarTitle(
        context,
        _dealLocked ? 'New order from deal' : 'New order',
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          controller: _listScrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: listPadding,
          children: [
            Text(
              'Orders are only created for Closed Won deals. Details below come from the funnel; adjust before submitting.',
              style: TextStyle(fontSize: 13, color: textSecondary, height: 1.35),
            ),
            SizedBox(height: AppSpacing.md),
            if (_dealLocked) ...[
              _LockedDealCard(
                sale: widget.closedWonSale!,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ] else ...[
              Text(
                'Closed Won deal *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              if (closedWonSales.isEmpty)
                Text(
                  'No Closed Won deals yet. Mark a deal as Closed Won in the funnel first.',
                  style: TextStyle(color: textSecondary, fontSize: 14),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor),
                  ),
                  child: SearchableDropdown<Sale>(
                    items: closedWonSales,
                    value: _pickedSale,
                    hintText: 'Select a Closed Won deal',
                    labelText: 'Deal',
                    dropdownColor: surfaceColor,
                    textColor: textPrimary,
                    hintColor: textSecondary,
                    itemLabelBuilder: (s) {
                      final co = s.company?.name ?? 'Company';
                      return '${s.prospect} · $co';
                    },
                    onChanged: (s) {
                      setState(() {
                        _pickedSale = s;
                        if (s != null) _applyPrefillFromSale(s);
                      });
                    },
                  ),
                ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _detailsController,
              style: TextStyle(color: textPrimary),
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Order details *',
                hintText: 'Product / service description',
                labelStyle: TextStyle(color: textSecondary),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: borderColor),
                ),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _revenueController,
              style: TextStyle(color: textPrimary),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Revenue',
                labelStyle: TextStyle(color: textSecondary),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: borderColor),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Assign to',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            KeyedSubtree(
              key: _assignFieldKey,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: SearchableDropdown<User>(
                  items: usersState.users,
                  value: _assignToId != null
                      ? usersState.users
                          .where((u) => u.id == _assignToId)
                          .firstOrNull
                      : null,
                  hintText: 'Optional',
                  labelText: 'User',
                  dropdownColor: surfaceColor,
                  textColor: textPrimary,
                  hintColor: textSecondary,
                  itemLabelBuilder: (u) => '${u.name} (${u.email})',
                  onChanged: (u) => setState(() => _assignToId = u?.id),
                  onMenuOpened: () {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _scrollAssignIntoView();
                    });
                    Future<void>.delayed(
                      const Duration(milliseconds: 160),
                      _scrollAssignIntoView,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            _OrderDatePickerField(
              label: 'Order confirmation date',
              date: _confirmed,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              borderColor: borderColor,
              primaryColor: primaryColor,
              onTap: () => _pickDate(
                current: _confirmed,
                onPick: (d) => setState(() => _confirmed = d),
              ),
            ),
            const SizedBox(height: 12),
            _OrderDatePickerField(
              label: 'Delivery date',
              date: _delivery,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              borderColor: borderColor,
              primaryColor: primaryColor,
              onTap: () => _pickDate(
                current: _delivery,
                onPick: (d) => setState(() => _delivery = d),
              ),
            ),
            SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: (_submitting || _effectiveSale == null)
                  ? null
                  : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create order'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Outlined, calendar-styled control so dates read as tappable fields (not plain list rows).
class _OrderDatePickerField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final Color textPrimary;
  final Color textSecondary;
  final Color borderColor;
  final Color primaryColor;
  final VoidCallback onTap;

  const _OrderDatePickerField({
    required this.label,
    required this.date,
    required this.textPrimary,
    required this.textSecondary,
    required this.borderColor,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label${date != null ? ', ${_formatOrderDateYmd(date!)}' : ''}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              hintText: 'Tap calendar to choose',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              suffixIcon: Icon(
                Icons.calendar_month_rounded,
                color: primaryColor,
                semanticLabel: 'Open date picker',
              ),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: borderColor),
              ),
            ),
            child: Text(
              date != null ? _formatOrderDateYmd(date!) : 'Select date',
              style: TextStyle(
                fontSize: 16,
                color: date != null ? textPrimary : textSecondary,
                fontWeight: date != null ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LockedDealCard extends StatelessWidget {
  final Sale sale;
  final Color textPrimary;
  final Color textSecondary;

  const _LockedDealCard({
    required this.sale,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: CRMCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Closed Won deal',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              sale.prospect,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            if (sale.company?.name != null) ...[
              const SizedBox(height: 4),
              Text(
                sale.company!.name,
                style: TextStyle(fontSize: 14, color: textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
