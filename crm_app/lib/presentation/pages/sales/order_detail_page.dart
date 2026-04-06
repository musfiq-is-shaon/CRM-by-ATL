import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme_colors.dart';
import '../../../data/models/company_model.dart';
import '../../../data/models/order_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/company_repository.dart';
import '../../../data/repositories/order_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../providers/order_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/crm_card.dart';
import '../../widgets/crm_text_field.dart';
import '../../widgets/error_widget.dart' as app_widgets;
import '../../widgets/loading_widget.dart';
import '../../widgets/status_badge.dart';
import 'sale_detail_page.dart';

const _kOrderStatusKeys = <String>[
  '',
  'pending',
  'open',
  'in_progress',
  'completed',
];

const _kNextActionKeys = <String>[
  '',
  'follow_up',
  'prepare_documents',
  'confirm_delivery',
  'renewal',
];

String _titleCaseSnake(String s) {
  if (s.isEmpty) return s;
  return s.split('_').map((w) {
    if (w.isEmpty) return w;
    return '${w[0].toUpperCase()}${w.substring(1)}';
  }).join(' ');
}

String _labelOrderStatus(String key) {
  if (key.isEmpty) return 'No status';
  return _titleCaseSnake(key);
}

String _labelNextAction(String key) {
  if (key.isEmpty) return 'None';
  return _titleCaseSnake(key);
}

String _normalizeStatus(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  final t = raw.trim().toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
  if (_kOrderStatusKeys.contains(t)) return t;
  for (final k in _kOrderStatusKeys) {
    if (k.isNotEmpty && _labelOrderStatus(k).toLowerCase() == raw.toLowerCase()) {
      return k;
    }
  }
  return t;
}

String _normalizeNextAction(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  final t = raw.trim().toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
  if (_kNextActionKeys.contains(t)) return t;
  for (final k in _kNextActionKeys) {
    if (k.isNotEmpty && _labelNextAction(k).toLowerCase() == raw.toLowerCase()) {
      return k;
    }
  }
  return t;
}

List<String> _keysWithUnknown(List<String> base, String current) {
  final out = List<String>.from(base);
  if (current.isNotEmpty && !out.contains(current)) {
    out.add(current);
  }
  return out;
}

class OrderDetailPage extends ConsumerStatefulWidget {
  final String orderId;

  const OrderDetailPage({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends ConsumerState<OrderDetailPage> {
  Order? _order;
  String? _error;
  bool _loading = true;
  bool _saving = false;

  String _statusKey = '';
  String _nextActionKey = '';
  DateTime? _nextActionDate;
  String _forwardedToId = '';

  final TextEditingController _scopeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(usersProvider.notifier).loadUsers();
    });
  }

  @override
  void dispose() {
    _scopeController.dispose();
    super.dispose();
  }

  void _applyOrderToForm(Order o) {
    _statusKey = _normalizeStatus(o.status);
    _nextActionKey = _normalizeNextAction(o.nextAction);
    _nextActionDate = o.nextActionDate;
    _forwardedToId = (o.forwardedTo ?? '').trim();
    _scopeController.text = o.orderDetails ?? '';
  }

  bool get _dirty {
    final o = _order;
    if (o == null) return false;
    if (_normalizeStatus(o.status) != _statusKey) return true;
    if (_normalizeNextAction(o.nextAction) != _nextActionKey) return true;
    if (!_sameDate(o.nextActionDate, _nextActionDate)) return true;
    if ((o.forwardedTo ?? '') != _forwardedToId) return true;
    return false;
  }

  bool _sameDate(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _error = null);
    }
    try {
      var o =
          await ref.read(orderRepositoryProvider).getOrderById(widget.orderId);
      o = await _enrichOrder(o);
      if (mounted) {
        setState(() {
          _order = o;
          _error = null;
          _applyOrderToForm(o);
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (silent && _order != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not refresh order. ${e.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
      } else {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final o = _order;
    if (o == null || !_dirty) return;
    setState(() => _saving = true);
    try {
      await ref.read(orderRepositoryProvider).patchOrder(
            id: o.id,
            status: _statusKey.isEmpty ? null : _statusKey,
            nextAction: _nextActionKey.isEmpty ? null : _nextActionKey,
            nextActionDate: _nextActionDate,
            forwardedTo: _forwardedToId.isEmpty ? '' : _forwardedToId,
          );
      await ref.read(ordersProvider.notifier).loadOrders();
      if (!mounted) return;
      await _load(silent: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<Order> _enrichOrder(Order o) async {
    final companyIds = <String>{};
    final userIds = <String>{};
    if (o.companyId != null && o.company == null) {
      companyIds.add(o.companyId!);
    }
    if (o.assignTo != null && o.assignToUser == null) {
      userIds.add(o.assignTo!);
    }
    if (o.forwardedTo != null && o.forwardedToUser == null) {
      userIds.add(o.forwardedTo!);
    }
    if (companyIds.isEmpty && userIds.isEmpty) return o;

    final companiesFuture = companyIds.isNotEmpty
        ? ref.read(companyRepositoryProvider).getCompaniesByIds(
              companyIds.toList(),
            )
        : Future.value(<String, Company>{});
    final usersFuture = userIds.isNotEmpty
        ? ref.read(userRepositoryProvider).getUsersByIds(userIds.toList())
        : Future.value(<String, User>{});

    final results = await Future.wait([companiesFuture, usersFuture]);
    final companiesMap = results[0] as Map<String, Company>;
    final usersMap = results[1] as Map<String, User>;

    Company? company = o.company;
    if (company == null && o.companyId != null) {
      company = companiesMap[o.companyId];
    }
    User? assignUser = o.assignToUser;
    if (assignUser == null && o.assignTo != null) {
      assignUser = usersMap[o.assignTo];
    }
    User? fwdUser = o.forwardedToUser;
    if (fwdUser == null && o.forwardedTo != null) {
      fwdUser = usersMap[o.forwardedTo];
    }
    return o.copyWith(
      company: company,
      assignToUser: assignUser,
      forwardedToUser: fwdUser,
    );
  }

  List<DropdownMenuItem<String>> _forwardDropdownItems(List<User> users) {
    final validUsers = users.where((u) => u.id.trim().isNotEmpty).toList();
    final ids = validUsers.map((u) => u.id).toSet();
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: '', child: Text('Not forwarded')),
      ...validUsers.map(
        (u) => DropdownMenuItem<String>(value: u.id, child: Text(u.name)),
      ),
    ];
    final fid = _forwardedToId;
    if (fid.isNotEmpty && !ids.contains(fid)) {
      items.add(
        DropdownMenuItem<String>(
          value: fid,
          child: Text(_order?.forwardedToUser?.name ?? fid),
        ),
      );
    }
    return items;
  }

  Future<void> _pickNextActionDue() async {
    final now = DateTime.now();
    final initial = _nextActionDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null && mounted) {
      setState(() => _nextActionDate = picked);
    }
  }

  String _fmt(DateTime? d) {
    if (d == null) return '—';
    return '${d.day}/${d.month}/${d.year}';
  }

  String _fmtFooter(DateTime? d) {
    if (d == null) return '—';
    return DateFormat('d MMM y').format(d);
  }

  InputDecoration _fieldDecoration(BuildContext context, String? label) {
    final o = Theme.of(context).colorScheme.outlineVariant;
    return InputDecoration(
      labelText: label,
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: o.withValues(alpha: 0.65)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: o.withValues(alpha: 0.65)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final textTertiary = AppThemeColors.textTertiaryColor(context);
    final primary = Theme.of(context).colorScheme.primary;
    final usersState = ref.watch(usersProvider);
    final users = usersState.users;

    return Scaffold(
      backgroundColor: AppThemeColors.backgroundColor(context),
      appBar: AppThemeColors.appBarTitle(
        context,
        'Order details',
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_order != null && !_loading && _error == null) ...[
            if (_dirty)
              TextButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                    : const Text('Save'),
              ),
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: _loading ? null : () => _load(silent: true),
            ),
          ],
        ],
      ),
      body: _loading
          ? const LoadingWidget()
          : _error != null
              ? app_widgets.ErrorWidget(message: _error!, onRetry: _load)
              : _order == null
                  ? const SizedBox.shrink()
                  : RefreshIndicator(
                      onRefresh: () => _load(silent: true),
                      child: ListView(
                        padding: AppThemeColors.pagePaddingAll,
                        children: [
                          CRMCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _order!.company?.name ?? 'Order',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _order!.orderDetails?.trim().isNotEmpty == true
                                      ? _order!.orderDetails!
                                      : '—',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textSecondary,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    if (_statusKey.isNotEmpty)
                                      StatusBadge(
                                        status: _statusKey,
                                        type: 'sale',
                                      )
                                    else
                                      Text(
                                        'No status',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: textTertiary,
                                        ),
                                      ),
                                    const Spacer(),
                                    Text(
                                      _order!.formattedRevenue,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          CRMCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Dates & assignment',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _row(
                                  textSecondary,
                                  textPrimary,
                                  'Order date',
                                  _fmt(_order!.orderConfirmationDate),
                                ),
                                _row(
                                  textSecondary,
                                  textPrimary,
                                  'Delivery',
                                  _fmt(_order!.deliveryDate),
                                ),
                                _row(
                                  textSecondary,
                                  textPrimary,
                                  'Assign to',
                                  _order!.assignToUser?.name ?? '—',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          CRMCard(
                            child: CRMTextField(
                              label: 'Order scope',
                              controller: _scopeController,
                              maxLines: 4,
                              enabled: false,
                              disableAutofill: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          CRMCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Workflow',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _dropdown(
                                  context,
                                  label: 'Status',
                                  value: _keysWithUnknown(
                                        _kOrderStatusKeys,
                                        _statusKey,
                                      ).contains(_statusKey)
                                      ? _statusKey
                                      : '',
                                  keys: _keysWithUnknown(
                                    _kOrderStatusKeys,
                                    _statusKey,
                                  ),
                                  labelFor: (k) => k.isEmpty
                                      ? _labelOrderStatus(k)
                                      : (_kOrderStatusKeys.contains(k)
                                          ? _labelOrderStatus(k)
                                          : _titleCaseSnake(k)),
                                  onChanged: (v) =>
                                      setState(() => _statusKey = v ?? ''),
                                ),
                                const SizedBox(height: 12),
                                _dropdown(
                                  context,
                                  label: 'Next to do',
                                  value: _keysWithUnknown(
                                        _kNextActionKeys,
                                        _nextActionKey,
                                      ).contains(_nextActionKey)
                                      ? _nextActionKey
                                      : '',
                                  keys: _keysWithUnknown(
                                    _kNextActionKeys,
                                    _nextActionKey,
                                  ),
                                  labelFor: (k) => k.isEmpty
                                      ? _labelNextAction(k)
                                      : (_kNextActionKeys.contains(k)
                                          ? _labelNextAction(k)
                                          : _titleCaseSnake(k)),
                                  onChanged: (v) =>
                                      setState(() => _nextActionKey = v ?? ''),
                                ),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: _pickNextActionDue,
                                  borderRadius: BorderRadius.circular(10),
                                  child: InputDecorator(
                                    decoration: _fieldDecoration(
                                      context,
                                      'Next to do due date',
                                    ).copyWith(
                                      suffixIcon: const Icon(
                                        Icons.calendar_today_outlined,
                                        size: 18,
                                      ),
                                    ),
                                    child: Text(
                                      _nextActionDate != null
                                          ? DateFormat('dd/MM/yyyy')
                                              .format(_nextActionDate!)
                                          : 'dd/mm/yyyy',
                                      style: TextStyle(
                                        color: _nextActionDate != null
                                            ? textPrimary
                                            : textTertiary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          CRMCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'People',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (_order!.createdByUser != null) ...[
                                  _row(
                                    textSecondary,
                                    textPrimary,
                                    'Assign by',
                                    _order!.createdByUser!.name,
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                Text(
                                  'Forwarded to',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Builder(
                                  builder: (context) {
                                    final fwdItems = _forwardDropdownItems(users);
                                    final fwdVal = fwdItems
                                            .any((e) => e.value == _forwardedToId)
                                        ? _forwardedToId
                                        : '';
                                    return InputDecorator(
                                      decoration: _fieldDecoration(
                                        context,
                                        null,
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          isExpanded: true,
                                          value: fwdVal,
                                          items: fwdItems,
                                          onChanged: (v) => setState(
                                                () => _forwardedToId =
                                                    (v ?? '').trim(),
                                              ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          if (_order!.salesId != null &&
                              _order!.salesId!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            CRMCard(
                              onTap: () {
                                Navigator.push<void>(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (context) => SaleDetailPage(
                                      saleId: _order!.salesId!,
                                    ),
                                  ),
                                );
                              },
                              child: Row(
                                children: [
                                  Icon(Icons.filter_alt_outlined, color: primary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Linked funnel deal',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: textPrimary,
                                          ),
                                        ),
                                        Text(
                                          'Open related deal',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right, color: textTertiary),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Text(
                            'Created ${_fmtFooter(_order!.createdAt)} · Updated ${_fmtFooter(_order!.updatedAt)}',
                            style: TextStyle(fontSize: 12, color: textTertiary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Order ID · ${_order!.id}',
                            style: TextStyle(fontSize: 11, color: textTertiary),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
    );
  }

  Widget _dropdown(
    BuildContext context, {
    required String label,
    required String value,
    required List<String> keys,
    required String Function(String) labelFor,
    required void Function(String?) onChanged,
  }) {
    return InputDecorator(
      decoration: _fieldDecoration(context, label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          items: keys
              .map(
                (k) => DropdownMenuItem(
                  value: k,
                  child: Text(labelFor(k)),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _row(
    Color secondary,
    Color primary,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: secondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: primary),
            ),
          ),
        ],
      ),
    );
  }
}
