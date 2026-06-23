import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/lunch_model.dart';
import '../../providers/lunch_provider.dart';
import '../../widgets/app_search_filter_bar.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/crm_card.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/error_widget.dart' as app_widgets;
import 'lunch_hub_chrome.dart';
import 'lunch_ui_helpers.dart';

class LunchOrderSummaryPage extends ConsumerStatefulWidget {
  const LunchOrderSummaryPage({super.key});

  @override
  ConsumerState<LunchOrderSummaryPage> createState() =>
      _LunchOrderSummaryPageState();
}

class _LunchOrderSummaryPageState extends ConsumerState<LunchOrderSummaryPage> {
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    await ref.read(lunchProvider.notifier).loadTodayPolls();
    final state = ref.read(lunchProvider);
    final pollId = state.selectedPollId ?? state.todayPolls.firstOrNull?.id;
    if (pollId != null && pollId.isNotEmpty) {
      await ref.read(lunchProvider.notifier).loadOrderSummary(pollId);
    } else {
      final now = DateTime.now();
      await ref.read(lunchProvider.notifier).loadAdminPolls(
        from: now.subtract(const Duration(days: 7)),
        to: now,
      );
      final adminPoll = ref.read(lunchProvider).adminPolls.firstOrNull;
      if (adminPoll != null) {
        await ref.read(lunchProvider.notifier).loadOrderSummary(adminPoll.id);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickPoll() async {
    final now = DateTime.now();
    await ref.read(lunchProvider.notifier).loadTodayPolls(silent: true);
    await ref.read(lunchProvider.notifier).loadAdminPolls(
      from: now.subtract(const Duration(days: 30)),
      to: now.add(const Duration(days: 7)),
    );
    if (!mounted) return;
    final state = ref.read(lunchProvider);
    final polls = [
      ...state.todayPolls,
      ...state.adminPolls.where(
        (p) => !state.todayPolls.any((t) => t.id == p.id),
      ),
    ];
    if (polls.isEmpty) return;
    final selected = await showModalBottomSheet<LunchPoll>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: polls
                .map(
                  (p) => ListTile(
                    title: Text(p.title),
                    subtitle: Text(formatLunchPollDateShort(p.date)),
                    trailing: lunchPollStatusBadge(p.effectiveStatus),
                    onTap: () => Navigator.pop(ctx, p),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
    if (selected != null && mounted) {
      await ref.read(lunchProvider.notifier).loadOrderSummary(selected.id);
    }
  }

  Future<void> _refresh() async {
    final pollId = ref.read(lunchProvider).selectedPollId;
    if (pollId == null) {
      await _bootstrap();
      return;
    }
    await ref.read(lunchProvider.notifier).loadTodayPolls(silent: true);
    await ref.read(lunchProvider.notifier).loadOrderSummary(pollId);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lunchProvider);
    final summary = state.orderSummary;
    final poll = summary?.poll ?? state.selectedPoll;
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final cs = Theme.of(context).colorScheme;

    ref.listen(lunchProvider, (prev, next) {
      if (next.error != null &&
          prev?.error != next.error &&
          context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)),
        );
        ref.read(lunchProvider.notifier).clearError();
      }
    });

    if (state.status == LunchLoadStatus.loading && summary == null) {
      return const LoadingWidget(message: 'Loading order summary…');
    }

    if (summary == null && state.status == LunchLoadStatus.error) {
      return app_widgets.ErrorWidget(
        message: state.error ?? 'Could not load order summary',
        onRetry: _bootstrap,
      );
    }

    if (poll == null) {
      return Center(
        child: Padding(
          padding: AppThemeColors.pagePaddingAll,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lunch_dining_outlined, size: 48, color: textSecondary),
              const SizedBox(height: 12),
              Text(
                'No lunch poll for this date',
                style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Create a poll or pick another date.',
                style: TextStyle(color: textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final employeeVotes = summary?.employeeVotes ?? const <LunchEmployeeVoteRow>[];
    final filteredVotes = employeeVotes.where((v) {
      if (_search.isEmpty) return true;
      return v.userName.toLowerCase().contains(_search.toLowerCase()) ||
          v.choice.toLowerCase().contains(_search.toLowerCase());
    }).toList();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: AppThemeColors.pagePaddingAll,
        children: [
          LunchPageTitle(
            title: 'Order summary',
            subtitle: poll.date != null
                ? '${DateFormat('EEE, MMM d, yyyy').format(poll.date!.toLocal())} · ${poll.title}'
                : poll.title,
            trailing: [
              if (summary != null)
                IconButton(
                  onPressed: () => exportLunchOrderSummaryPdf(summary),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  tooltip: 'Export PDF',
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickPoll,
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: const Text('Choose poll'),
                ),
              ),
              if (poll != null) ...[
                const SizedBox(width: 8),
                lunchPollStatusBadge(poll.effectiveStatus),
              ],
            ],
          ),
          if (summary != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Office',
                    value: '${summary.officeOrders}',
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    label: 'Personal',
                    value: '${summary.personalCount}',
                    color: cs.secondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    label: 'Total votes',
                    value: '${summary.totalVotes}',
                    color: cs.tertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Menu breakdown',
              style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary),
            ),
            const SizedBox(height: 8),
            if (summary.menuBreakdown.isEmpty)
              CRMCard(
                child: Text('No menu data', style: TextStyle(color: textSecondary)),
              )
            else
              ...summary.menuBreakdown.map(
                (row) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: CRMCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.label,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              lunchOptionTypeBadge(row.optionType),
                            ],
                          ),
                        ),
                        Text(
                          '${row.votes}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Text(
              'Employee votes (${employeeVotes.length})',
              style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary),
            ),
            const SizedBox(height: 8),
            AppSearchFilterBar(
              controller: _searchController,
              hintText: 'Search employees…',
              activeFilterCount: 0,
              onChanged: (v) => setState(() => _search = v.trim()),
              onClear: () {
                _searchController.clear();
                setState(() => _search = '');
              },
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            if (filteredVotes.isEmpty)
              CRMCard(
                child: Text(
                  _search.isEmpty
                      ? 'No votes recorded for this poll'
                      : 'No employees match your search',
                  style: TextStyle(color: textSecondary),
                ),
              )
            else
              ...filteredVotes.map(
                (v) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: CRMCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AvatarWidget(name: v.userName, size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                v.userName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                v.choice.isNotEmpty ? v.choice : '—',
                                style: TextStyle(fontSize: 13, color: textSecondary),
                              ),
                              if (v.optionType.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                lunchOptionTypeBadge(v.optionType),
                              ],
                            ],
                          ),
                        ),
                        if (v.votedAt != null)
                          Text(
                            formatLunchVoteTime(v.votedAt),
                            style: TextStyle(fontSize: 12, color: textSecondary),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemeColors.cardColor(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppThemeColors.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: textSecondary)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (it.moveNext()) return it.current;
    return null;
  }
}
