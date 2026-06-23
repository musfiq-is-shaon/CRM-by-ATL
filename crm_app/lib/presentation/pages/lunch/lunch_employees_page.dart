import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../providers/lunch_provider.dart';
import '../../widgets/app_search_filter_bar.dart';
import '../../widgets/crm_card.dart';
import '../../widgets/crm_text_field.dart';
import '../../widgets/loading_widget.dart';
import '../../../data/models/lunch_model.dart';
import 'lunch_hub_chrome.dart';

class LunchEmployeesPage extends ConsumerStatefulWidget {
  const LunchEmployeesPage({super.key});

  @override
  ConsumerState<LunchEmployeesPage> createState() => _LunchEmployeesPageState();
}

class _LunchEmployeesPageState extends ConsumerState<LunchEmployeesPage> {
  late DateTime _from;
  late DateTime _to;
  String _search = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month + 1, 0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await ref.read(lunchProvider.notifier).loadEmployeeBalances(from: _from, to: _to);
  }

  int get _activeFilterCount {
    var n = 0;
    final now = DateTime.now();
    if (_from != DateTime(now.year, now.month, 1) ||
        _to != DateTime(now.year, now.month + 1, 0)) {
      n++;
    }
    return n;
  }

  List<String> get _filterLabels => [
    '${DateFormat('MMM d').format(_from)} – ${DateFormat('MMM d, yyyy').format(_to)}',
  ];

  void _showFilterSheet() {
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final primaryColor = Theme.of(context).colorScheme.primary;
    var from = _from;
    var to = _to;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filters',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      final now = DateTime.now();
                      setModal(() {
                        from = DateTime(now.year, now.month, 1);
                        to = DateTime(now.year, now.month + 1, 0);
                      });
                    },
                    child: Text('Clear', style: TextStyle(color: primaryColor)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: ctx,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDateRange: DateTimeRange(start: from, end: to),
                  );
                  if (picked != null) {
                    setModal(() {
                      from = picked.start;
                      to = picked.end;
                    });
                  }
                },
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(
                  '${DateFormat('MMM d').format(from)} – ${DateFormat('MMM d, yyyy').format(to)}',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _from = from;
                    _to = to;
                  });
                  Navigator.pop(ctx);
                  _load();
                },
                child: const Text('Apply'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAdjustDialog(LunchEmployeeBalance row) async {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController(text: 'Correction');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Adjust balance — ${row.userName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CRMTextField(
              controller: amountCtrl,
              label: 'Amount (${AppConstants.currencySymbol})',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 8),
            CRMTextField(controller: reasonCtrl, label: 'Reason'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    final amount = num.tryParse(amountCtrl.text.trim());
    if (amount == null) return;
    await ref.read(lunchProvider.notifier).adjustBalance(
      userId: row.userId,
      amount: amount,
      reason: reasonCtrl.text.trim(),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lunchProvider);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final cs = Theme.of(context).colorScheme;

    final rows = state.employeeBalances.where((r) {
      if (_search.isEmpty) return true;
      return r.userName.toLowerCase().contains(_search.toLowerCase());
    }).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: AppThemeColors.pagePaddingAll,
        children: [
          const LunchPageTitle(
            title: 'Employees',
            subtitle: 'Lunch balance by employee for the selected period.',
          ),
          AppSearchFilterBar(
            controller: _searchController,
            hintText: 'Search employees…',
            activeFilterCount: _activeFilterCount,
            onChanged: (v) => setState(() => _search = v.trim()),
            onClear: () {
              _searchController.clear();
              setState(() => _search = '');
            },
            onFilterTap: _showFilterSheet,
            padding: const EdgeInsets.only(top: 12, bottom: 8),
          ),
          LunchActiveFiltersRow(
            labels: _filterLabels,
            onRemove: (_) {
              final now = DateTime.now();
              setState(() {
                _from = DateTime(now.year, now.month, 1);
                _to = DateTime(now.year, now.month + 1, 0);
              });
              _load();
            },
          ),
          if (state.status == LunchLoadStatus.loading && state.employeeBalances.isEmpty)
            const LoadingWidget(message: 'Loading balances…')
          else if (rows.isEmpty)
            CRMCard(
              child: Text(
                _search.isEmpty ? 'No employee data' : 'No employees match your search',
                style: TextStyle(color: textSecondary),
              ),
            )
          else
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: CRMCard(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: cs.primaryContainer,
                        child: Text(
                          row.userName.isNotEmpty ? row.userName[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 14,
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          row.userName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${row.balance} ${AppConstants.currencySymbol}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: row.balance < 0 ? cs.error : textPrimary,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _showAdjustDialog(row),
                        icon: const Icon(Icons.tune, size: 18),
                        tooltip: 'Adjust balance',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
