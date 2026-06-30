import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/lunch_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lunch_provider.dart';
import '../../widgets/crm_card.dart';
import '../../widgets/error_widget.dart' as app_widgets;
import '../../widgets/loading_widget.dart';
import 'lunch_poll_option_row.dart';
import 'lunch_ui_helpers.dart';
import 'lunch_vote_history_sheet.dart';

class LunchMyLunchPage extends ConsumerStatefulWidget {
  const LunchMyLunchPage({super.key});

  @override
  ConsumerState<LunchMyLunchPage> createState() => _LunchMyLunchPageState();
}

class _LunchMyLunchPageState extends ConsumerState<LunchMyLunchPage> {
  late DateTime _balanceMonth;

  @override
  void initState() {
    super.initState();
    _balanceMonth = DateTime(DateTime.now().year, DateTime.now().month);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final n = ref.read(lunchProvider.notifier);
    await n.bootstrapUser();
    await n.loadSettings();
    await n.loadMyBalance(month: _monthKey(_balanceMonth), silent: true);
  }

  Future<void> _refresh() async {
    await ref.read(lunchProvider.notifier).loadTodayPolls();
    await ref.read(lunchProvider.notifier).loadMyBalance(month: _monthKey(_balanceMonth));
  }

  String _monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  void _shiftMonth(int delta) {
    setState(() {
      _balanceMonth = DateTime(_balanceMonth.year, _balanceMonth.month + delta);
    });
    ref.read(lunchProvider.notifier).loadMyBalance(
      month: _monthKey(_balanceMonth),
      silent: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lunchProvider);
    final user = ref.watch(authProvider).user;
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);

    if (state.status == LunchLoadStatus.loading && state.todayPolls.isEmpty) {
      return ListView(
        padding: AppThemeColors.pagePaddingAll,
        children: const [
          ShimmerCard(height: 76),
          SizedBox(height: AppSpacing.md),
          ShimmerCard(height: 200),
          SizedBox(height: AppSpacing.md),
          ShimmerCard(height: 160),
        ],
      );
    }

    if (state.status == LunchLoadStatus.error && state.todayPolls.isEmpty) {
      return app_widgets.ErrorWidget(
        message: state.error ?? 'Could not load lunch polls',
        onRetry: _bootstrap,
      );
    }

    final poll = state.todayPolls.isNotEmpty ? state.todayPolls.first : null;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 640;
          final pollCard = poll != null
              ? _TodayPollCard(poll: poll, userName: user?.name ?? 'You')
              : CRMCard(
                  child: Column(
                    children: [
                      AppThemeColors.iconChip(
                        context,
                        icon: Icons.lunch_dining_outlined,
                        accent: textSecondary,
                        size: 52,
                        iconSize: 26,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'No lunch poll today',
                        style: AppTypography.sectionTitle(context)?.copyWith(
                              color: textPrimary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Check back later — your team admin may publish a poll soon.',
                        style: TextStyle(color: textSecondary, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
          final balanceCard = _BalanceCard(
            month: _balanceMonth,
            balance: state.myBalance,
            onPrev: () => _shiftMonth(-1),
            onNext: () => _shiftMonth(1),
          );

          return ListView(
            padding: AppThemeColors.pagePaddingAll,
            children: [
              const LunchModuleHeader(),
              const SizedBox(height: AppSpacing.sm),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: pollCard),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(flex: 2, child: balanceCard),
                  ],
                )
              else ...[
                pollCard,
                const SizedBox(height: AppSpacing.md),
                balanceCard,
              ],
              const SizedBox(height: AppSpacing.sm),
              _VoteHistoryTeaser(
                onTap: () => showLunchVoteHistorySheet(context),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          );
        },
      ),
    );
  }
}

class _TodayPollCard extends ConsumerWidget {
  const _TodayPollCard({required this.poll, required this.userName});

  final LunchPoll poll;
  final String userName;

  String get _statusHint {
    if (poll.isCancelled) return 'Poll cancelled — voting is disabled';
    if (poll.effectiveStatus == 'closed') {
      if (poll.isPastEndTime && poll.isActive) {
        return 'Voting ended at ${formatLunchEndTimeDisplay(poll.endTime)}';
      }
      return 'Poll closed — voting has ended';
    }
    if (poll.isVotingOpen && poll.endTime != null && poll.endTime!.isNotEmpty) {
      return 'Closes at ${formatLunchEndTimeDisplay(poll.endTime)}';
    }
    return poll.statusHint;
  }

  IconData get _statusIcon {
    if (poll.isCancelled) return Icons.cancel_outlined;
    if (poll.effectiveStatus == 'closed') return Icons.lock_outline;
    return Icons.schedule;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(lunchProvider);
    final voting = state.votingPollId == poll.id;
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final cs = Theme.of(context).colorScheme;
    final canVote = poll.isVotingOpen;
    final myOptionId = poll.myVote?.optionId;
    final hasVoted = myOptionId != null;
    final optionsLocked =
        voting || (hasVoted && !poll.allowVoteChange) || !canVote;
    final options = poll.mergedOptions;
    final total = poll.totalVoteCount;

    return CRMCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: lunchBrandGreen,
                      ),
                    ),
                    Text(
                      poll.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              lunchPollStatusBadge(poll.effectiveStatus),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: poll.isCancelled
                  ? cs.errorContainer.withValues(alpha: 0.35)
                  : poll.effectiveStatus == 'closed'
                  ? cs.surfaceContainerHighest
                  : cs.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: poll.effectiveStatus == 'closed'
                  ? Border.all(color: cs.outline.withValues(alpha: 0.35))
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  _statusIcon,
                  size: 14,
                  color: poll.isCancelled
                      ? cs.error
                      : poll.effectiveStatus == 'closed'
                      ? cs.onSurfaceVariant
                      : textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _statusHint,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: poll.effectiveStatus == 'closed' || poll.isCancelled
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: poll.isCancelled
                          ? cs.error
                          : poll.effectiveStatus == 'closed'
                          ? cs.onSurfaceVariant
                          : textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (options.isEmpty)
            Text('No menu options yet', style: TextStyle(color: textSecondary))
          else
            AbsorbPointer(
              absorbing: optionsLocked,
              child: Opacity(
                opacity: optionsLocked ? 0.42 : 1,
                child: Column(
                  children: options
                      .map(
                        (opt) => LunchPollOptionRow(
                          option: opt,
                          selected: myOptionId == opt.id,
                          totalVotes: total,
                          enabled: !optionsLocked,
                          compact: true,
                          onTap: () async {
                            if (optionsLocked) {
                              if (!canVote) {
                                showLunchVoteDisabledMessage(context, poll);
                              }
                              return;
                            }
                            if (!poll.allowVoteChange &&
                                myOptionId != null &&
                                myOptionId != opt.id) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Vote changes are not allowed'),
                                ),
                              );
                              return;
                            }
                            await ref
                                .read(lunchProvider.notifier)
                                .vote(poll.id, opt.id);
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          if (poll.myVote?.votedAt != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Voted ${formatLunchVoteTime(poll.myVote!.votedAt)}',
                style: TextStyle(fontSize: 10, color: textSecondary),
              ),
            ),
          ],
          if (total > 0) ...[
            const SizedBox(height: 2),
            Center(
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => showLunchPollVotesSheet(context, poll),
                child: const Text(
                  'View all votes',
                  style: TextStyle(
                    fontSize: 13,
                    color: lunchBrandGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.month,
    required this.balance,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime month;
  final LunchBalanceMe? balance;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final cs = Theme.of(context).colorScheme;
    final bal = balance?.balance ?? 0;
    final isOwed = bal < 0;
    final monthLabel = DateFormat('MMMM yyyy').format(month);

    return CRMCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LUNCH BALANCE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton(
                onPressed: onPrev,
                icon: const Icon(Icons.chevron_left),
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Text(
                  monthLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary),
                ),
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$bal ${AppConstants.currencySymbol}',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: isOwed ? cs.error : lunchBrandGreen,
              height: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (isOwed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: cs.errorContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Amount owed',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cs.error,
                ),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            'Net change for $monthLabel: ${balance?.monthNetChange ?? 0}',
            style: TextStyle(fontSize: 12, color: textSecondary),
          ),
        ],
      ),
    );
  }
}

class _VoteHistoryTeaser extends StatelessWidget {
  const _VoteHistoryTeaser({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    return CRMCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: lunchBrandPurple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.history, color: lunchBrandPurple, size: 22),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vote history',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: textPrimary,
                  ),
                ),
                Text(
                  'Your meals & balance — one entry per day',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: textSecondary),
        ],
      ),
    );
  }
}
