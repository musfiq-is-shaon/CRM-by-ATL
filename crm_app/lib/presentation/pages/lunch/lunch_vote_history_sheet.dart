import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/lunch_model.dart';
import '../../providers/lunch_provider.dart';
import '../../widgets/loading_widget.dart';
import 'lunch_ui_helpers.dart';

enum _HistoryPreset { thisMonth, last7Days, lastMonth, custom }

Future<void> showLunchVoteHistorySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppThemeColors.backgroundColor(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _LunchVoteHistorySheet(),
  );
}

class _LunchVoteHistorySheet extends ConsumerStatefulWidget {
  const _LunchVoteHistorySheet();

  @override
  ConsumerState<_LunchVoteHistorySheet> createState() =>
      _LunchVoteHistorySheetState();
}

class _LunchVoteHistorySheetState extends ConsumerState<_LunchVoteHistorySheet> {
  late DateTime _from;
  late DateTime _to;
  _HistoryPreset _preset = _HistoryPreset.thisMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month + 1, 0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _applyPreset(_HistoryPreset preset) {
    final now = DateTime.now();
    late DateTime from;
    late DateTime to;
    switch (preset) {
      case _HistoryPreset.thisMonth:
        from = DateTime(now.year, now.month, 1);
        to = DateTime(now.year, now.month + 1, 0);
      case _HistoryPreset.last7Days:
        from = now.subtract(const Duration(days: 6));
        to = now;
      case _HistoryPreset.lastMonth:
        from = DateTime(now.year, now.month - 1, 1);
        to = DateTime(now.year, now.month, 0);
      case _HistoryPreset.custom:
        return;
    }
    setState(() {
      _preset = preset;
      _from = from;
      _to = to;
    });
    _load();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _preset = _HistoryPreset.custom;
      _from = picked.start;
      _to = picked.end;
    });
    _load();
  }

  Future<void> _load() async {
    await ref.read(lunchProvider.notifier).loadVoteHistory(from: _from, to: _to);
  }

  String get _rangeLabel {
    final sameMonth = _from.year == _to.year && _from.month == _to.month;
    if (sameMonth && _from.day == 1 && _to.day == DateTime(_to.year, _to.month + 1, 0).day) {
      return DateFormat('MMM yyyy').format(_from);
    }
    return '${DateFormat('MMM d').format(_from)} – ${DateFormat('MMM d, yyyy').format(_to)}';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lunchProvider);
    final rows = state.voteHistory;
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final cs = Theme.of(context).colorScheme;
    final border = AppThemeColors.borderColor(context);

    final total = rows.fold<num>(0, (s, r) => s + (r.amount ?? 0));
    final daysWithVotes = rows
        .map((r) => r.pollDate != null ? DateFormat('yyyy-MM-dd').format(r.pollDate!) : '')
        .where((d) => d.isNotEmpty)
        .toSet()
        .length;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: lunchBrandPurple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.history, color: lunchBrandPurple),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vote history',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          'Your votes and balance changes per poll.',
                          style: TextStyle(fontSize: 13, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PresetChip(
                    label: 'This month',
                    selected: _preset == _HistoryPreset.thisMonth,
                    onTap: () => _applyPreset(_HistoryPreset.thisMonth),
                  ),
                  _PresetChip(
                    label: 'Last 7 days',
                    selected: _preset == _HistoryPreset.last7Days,
                    onTap: () => _applyPreset(_HistoryPreset.last7Days),
                  ),
                  _PresetChip(
                    label: 'Last month',
                    selected: _preset == _HistoryPreset.lastMonth,
                    onTap: () => _applyPreset(_HistoryPreset.lastMonth),
                  ),
                  InkWell(
                    onTap: _pickRange,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: border),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 14, color: textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            _rangeLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                          Icon(Icons.expand_more, size: 18, color: textSecondary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOTAL FOR RANGE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: textSecondary,
                          ),
                        ),
                        Text(
                          '$daysWithVotes day${daysWithVotes == 1 ? '' : 's'} with votes',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$total ${AppConstants.currencySymbol}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: total < 0 ? cs.error : lunchBrandGreen,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: state.status == LunchLoadStatus.loading && rows.isEmpty
                  ? const LoadingWidget(message: 'Loading history…')
                  : rows.isEmpty
                  ? Center(
                      child: Text(
                        'No votes in this range',
                        style: TextStyle(color: textSecondary),
                      ),
                    )
                  : ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      children: [
                        _HistoryTableHeader(textSecondary: textSecondary),
                        const Divider(height: 1),
                        ...rows.map((r) => _HistoryRow(row: r)),
                        const Divider(height: 1),
                        _HistoryTotalFooter(total: total, textSecondary: textSecondary),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      selectedColor: lunchBrandPurple.withValues(alpha: 0.15),
      checkmarkColor: lunchBrandPurple,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: selected ? lunchBrandPurple : null,
      ),
      onSelected: (_) => onTap(),
    );
  }
}

class _HistoryTableHeader extends StatelessWidget {
  const _HistoryTableHeader({required this.textSecondary});

  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    TextStyle h() => TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
      color: lunchBrandPurple,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('DATE', style: h())),
          Expanded(flex: 4, child: Text('MENU ITEM', style: h())),
          Expanded(flex: 2, child: Text('TYPE', style: h())),
          Expanded(
            flex: 2,
            child: Text('AMOUNT', style: h(), textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.row});

  final LunchVoteHistoryRow row;

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final cs = Theme.of(context).colorScheme;
    final kind = row.optionType != null ? lunchOptionKindFrom(row.optionType) : null;
    final amount = row.amount;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.pollDate != null
                      ? DateFormat('MMM d, yyyy').format(row.pollDate!.toLocal())
                      : '—',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: textPrimary,
                  ),
                ),
                Text(
                  row.pollTitle,
                  style: TextStyle(fontSize: 11, color: textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              row.menuItem ?? '—',
              style: TextStyle(fontSize: 13, color: textPrimary),
            ),
          ),
          Expanded(
            flex: 2,
            child: kind != null
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: lunchOptionTypeBadge(
                      row.optionType!,
                      fontSize: 9,
                      shortLabel: true,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(
            flex: 2,
            child: Text(
              amount != null ? '$amount ${AppConstants.currencySymbol}' : '—',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: amount != null && amount < 0 ? cs.error : textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTotalFooter extends StatelessWidget {
  const _HistoryTotalFooter({required this.total, required this.textSecondary});

  final num total;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 9,
            child: Text(
              'TOTAL FOR RANGE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '$total ${AppConstants.currencySymbol}',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: total < 0 ? cs.error : lunchBrandGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
