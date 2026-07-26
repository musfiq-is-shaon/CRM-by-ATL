import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../providers/lunch_provider.dart';
import '../../widgets/crm_card.dart';
import '../../widgets/loading_widget.dart';
import 'lunch_ui_helpers.dart';

class LunchBalancePage extends ConsumerStatefulWidget {
  const LunchBalancePage({super.key});

  @override
  ConsumerState<LunchBalancePage> createState() => _LunchBalancePageState();
}

class _LunchBalancePageState extends ConsumerState<LunchBalancePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final month = DateFormat('yyyy-MM').format(DateTime.now());
      ref.read(lunchProvider.notifier).loadMyBalance(month: month);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lunchProvider);
    final bal = state.myBalance;
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final cs = Theme.of(context).colorScheme;

    if (state.myBalanceLoading && bal == null) {
      return const ListSkeletonLoader(
        padding: AppThemeColors.pagePaddingAll,
        itemCount: 5,
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final month = DateFormat('yyyy-MM').format(DateTime.now());
        await ref.read(lunchProvider.notifier).loadMyBalance(month: month);
      },
      child: ListView(
        padding: AppThemeColors.pagePaddingAll,
        children: [
          Text(
            'My balance',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: textPrimary),
          ),
          const SizedBox(height: 16),
          CRMCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current balance', style: TextStyle(color: textSecondary, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  bal == null
                      ? 'Balance unavailable'
                      : '${AppConstants.currencySymbol}${bal.balance}',
                  style: TextStyle(
                    fontSize: bal == null ? 18 : 32,
                    fontWeight: FontWeight.w800,
                    color: bal == null ? textSecondary : cs.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  bal == null
                      ? 'Pull to refresh'
                      : 'This month: ${bal.monthNetChange}',
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Recent transactions',
            style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary),
          ),
          const SizedBox(height: 8),
          if (state.transactions.isEmpty)
            CRMCard(
              child: Text('No transactions', style: TextStyle(color: textSecondary)),
            )
          else
            ...state.transactions.map(
              (tx) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CRMCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tx.reason ?? tx.type ?? 'Transaction',
                              style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary),
                            ),
                            if (tx.createdAt != null)
                              Text(
                                DateFormat('MMM d, yyyy').format(tx.createdAt!.toLocal()),
                                style: TextStyle(fontSize: 12, color: textSecondary),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        '${tx.amount >= 0 ? '+' : ''}${tx.amount}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: tx.amount >= 0 ? cs.tertiary : cs.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class LunchHistoryPage extends ConsumerStatefulWidget {
  const LunchHistoryPage({super.key});

  @override
  ConsumerState<LunchHistoryPage> createState() => _LunchHistoryPageState();
}

class _LunchHistoryPageState extends ConsumerState<LunchHistoryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final now = DateTime.now();
    await ref.read(lunchProvider.notifier).loadVoteHistory(
      from: DateTime(now.year, now.month, 1),
      to: now,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lunchProvider);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: AppThemeColors.pagePaddingAll,
        children: [
          Text(
            'Vote history',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Your past lunch choices.',
            style: TextStyle(fontSize: 13, color: textSecondary),
          ),
          const SizedBox(height: 16),
          if (state.status == LunchLoadStatus.loading && state.voteHistory.isEmpty)
            const ListSkeletonLoader(itemCount: 4, shrinkWrap: true)
          else if (state.voteHistory.isEmpty)
            CRMCard(child: Text('No history yet', style: TextStyle(color: textSecondary)))
          else
            ...state.voteHistory.map(
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
                              row.pollTitle,
                              style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary),
                            ),
                            if (row.pollDate != null)
                              Text(
                                formatLunchPollDateShort(row.pollDate),
                                style: TextStyle(fontSize: 12, color: textSecondary),
                              ),
                            if (row.optionType != null) ...[
                              const SizedBox(height: 4),
                              lunchOptionTypeBadge(row.optionType!),
                            ],
                          ],
                        ),
                      ),
                      if (row.votedAt != null)
                        Text(
                          formatLunchVoteTime(row.votedAt),
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
