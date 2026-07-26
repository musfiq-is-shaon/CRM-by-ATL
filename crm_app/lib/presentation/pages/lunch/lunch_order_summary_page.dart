import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/friendly_error_message.dart';
import '../../../data/models/lunch_model.dart';
import '../../providers/lunch_provider.dart';
import '../../widgets/app_search_filter_bar.dart';
import '../../widgets/app_section_header.dart';
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
  bool _initialLoadComplete = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    await ref.read(lunchProvider.notifier).bootstrapOrderSummary();
    if (mounted) setState(() => _initialLoadComplete = true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickPoll() async {
    if (!mounted) return;
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 30));
    final to = now.add(const Duration(days: 7));
    final cached = _pollPickerCandidates(ref.read(lunchProvider));

    final selected = await showModalBottomSheet<LunchPoll>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _PollPickerSheet(
        initialPolls: cached,
        loadPolls: () => ref.read(lunchProvider.notifier).loadPollPickerOptions(
          from: from,
          to: to,
        ),
      ),
    );
    if (selected != null && mounted) {
      await ref
          .read(lunchProvider.notifier)
          .loadOrderSummary(selected.id, silent: false);
    }
  }

  List<LunchPoll> _pollPickerCandidates(LunchState state) {
    final byId = <String, LunchPoll>{};
    for (final poll in state.todayPolls) {
      if (poll.id.isNotEmpty) byId[poll.id] = poll;
    }
    for (final poll in state.adminPolls) {
      if (poll.id.isNotEmpty) byId[poll.id] = poll;
    }
    return byId.values.toList()
      ..sort((a, b) {
        final ad = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
  }

  Future<void> _refresh() async {
    final pollId = ref.read(lunchProvider).selectedPollId;
    if (pollId == null) {
      await _bootstrap();
      return;
    }
    await ref.read(lunchProvider.notifier).loadTodayPolls(silent: true);
    await ref
        .read(lunchProvider.notifier)
        .loadOrderSummary(pollId, silent: ref.read(lunchProvider).orderSummary != null);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lunchProvider);
    final summary = state.orderSummary;
    final poll = summary?.poll ?? state.selectedPoll;
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final cs = Theme.of(context).colorScheme;

    if ((state.orderSummaryLoading || !_initialLoadComplete) &&
        summary == null &&
        state.orderSummaryError == null) {
      return const ListSkeletonLoader(
        padding: AppThemeColors.pagePaddingAll,
        itemCount: 6,
      );
    }

    if (summary == null &&
        !state.orderSummaryLoading &&
        state.orderSummaryError != null) {
      return app_widgets.ErrorWidget(
        message: state.orderSummaryError ?? 'Could not load order summary',
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
              const SizedBox(height: AppSpacing.sm),
              Text(
                'No lunch poll for this date',
                style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.xs),
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

    if (summary == null) {
      return Center(
        child: Padding(
          padding: AppThemeColors.pagePaddingAll,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long_outlined, size: 48, color: textSecondary),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'No order summary yet',
                style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Pull to refresh or choose another poll.',
                style: TextStyle(color: textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: _bootstrap,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final employeeVotes = summary.employeeVotes;
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
              IconButton(
                onPressed: () async {
                  try {
                    await exportLunchOrderSummaryPdf(summary);
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(friendlyErrorMessage(e))),
                    );
                  }
                },
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: 'Export PDF',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickPoll,
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: const Text('Choose poll'),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              lunchPollStatusBadge(poll.effectiveStatus),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Office',
                  value: '${summary.officeOrders}',
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _StatCard(
                  label: 'Personal',
                  value: '${summary.personalCount}',
                  color: cs.secondary,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _StatCard(
                  label: 'Total votes',
                  value: '${summary.totalVotes}',
                  color: cs.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppThemeColors.sectionGap),
          const AppSectionHeader(title: 'Menu breakdown'),
          const SizedBox(height: AppSpacing.xs),
          if (summary.menuBreakdown.isEmpty)
            CRMCard(
              child: Text('No menu data', style: TextStyle(color: textSecondary)),
            )
          else
            ...summary.menuBreakdown.map(
              (row) => Padding(
                padding: AppThemeColors.cardListItemMargin,
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
          const SizedBox(height: AppThemeColors.sectionGap),
          AppSectionHeader(
            title: 'Employee votes (${employeeVotes.length})',
          ),
          const SizedBox(height: AppSpacing.xs),
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
          const SizedBox(height: AppSpacing.xs),
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
                padding: AppThemeColors.cardListItemMargin,
                child: CRMCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AvatarWidget(name: v.userName, size: 36),
                      const SizedBox(width: AppSpacing.sm),
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
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _PollPickerSheet extends StatefulWidget {
  const _PollPickerSheet({
    required this.initialPolls,
    required this.loadPolls,
  });

  final List<LunchPoll> initialPolls;
  final Future<List<LunchPoll>> Function() loadPolls;

  @override
  State<_PollPickerSheet> createState() => _PollPickerSheetState();
}

class _PollPickerSheetState extends State<_PollPickerSheet> {
  late List<LunchPoll> _polls;
  late bool _loading;
  var _refreshing = false;

  @override
  void initState() {
    super.initState();
    _polls = widget.initialPolls;
    _loading = widget.initialPolls.isEmpty;
    _refresh();
  }

  Future<void> _refresh() async {
    if (_polls.isEmpty) {
      setState(() => _loading = true);
    } else {
      setState(() => _refreshing = true);
    }
    try {
      final fresh = await widget.loadPolls();
      if (mounted) {
        setState(() {
          _polls = fresh;
          _loading = false;
          _refreshing = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppThemeColors.textSecondaryColor(context);

    if (_loading && _polls.isEmpty) {
      return const SafeArea(
        child: ListSkeletonLoader(
          itemCount: 4,
          shrinkWrap: true,
          padding: EdgeInsets.all(AppSpacing.md),
        ),
      );
    }

    if (_polls.isEmpty) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No polls found',
            textAlign: TextAlign.center,
            style: TextStyle(color: textSecondary),
          ),
        ),
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_refreshing)
            const LinearProgressIndicator(minHeight: 2),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: _polls
                  .map(
                    (p) => ListTile(
                      title: Text(p.title),
                      subtitle: Text(formatLunchPollDateShort(p.date)),
                      trailing: lunchPollStatusBadge(p.effectiveStatus),
                      onTap: () => Navigator.pop(context, p),
                    ),
                  )
                  .toList(),
            ),
          ),
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
