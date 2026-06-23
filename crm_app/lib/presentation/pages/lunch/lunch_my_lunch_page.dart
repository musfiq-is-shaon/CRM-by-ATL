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
    await n.loadMyBalance(month: _monthKey(_balanceMonth));
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
    ref.read(lunchProvider.notifier).loadMyBalance(month: _monthKey(_balanceMonth));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lunchProvider);
    final user = ref.watch(authProvider).user;
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);

    if (state.status == LunchLoadStatus.loading && state.todayPolls.isEmpty) {
      return const LoadingWidget(message: 'Loading today\'s lunch…');
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
                      Icon(Icons.lunch_dining_outlined, size: 40, color: textSecondary),
                      const SizedBox(height: 8),
                      Text(
                        'No lunch poll today',
                        style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Check back later.',
                        style: TextStyle(color: textSecondary, fontSize: 13),
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
              const SizedBox(height: 20),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: pollCard),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: balanceCard),
                  ],
                )
              else ...[
                pollCard,
                const SizedBox(height: 16),
                balanceCard,
              ],
              const SizedBox(height: 12),
              _VoteHistoryTeaser(
                onTap: () => showLunchVoteHistorySheet(context),
              ),
              const SizedBox(height: 24),
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
    if (poll.isActive && poll.endTime != null && poll.endTime!.isNotEmpty) {
      return 'Closes at ${formatLunchEndTimeDisplay(poll.endTime)}';
    }
    return poll.statusHint;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(lunchProvider);
    final voting = state.votingPollId == poll.id;
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final cs = Theme.of(context).colorScheme;
    final canVote = poll.isActive;
    final myOptionId = poll.myVote?.optionId;
    final options = poll.mergedOptions;
    final total = poll.totalVoteCount;

    return CRMCard(
      padding: const EdgeInsets.all(16),
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
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: lunchBrandGreen,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      poll.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              lunchPollStatusBadge(poll.status),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: poll.isCancelled
                  ? cs.errorContainer.withValues(alpha: 0.35)
                  : cs.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                Icon(
                  poll.isCancelled ? Icons.cancel_outlined : Icons.schedule,
                  size: 16,
                  color: poll.isCancelled ? cs.error : textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _statusHint,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: poll.isCancelled ? cs.error : textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (voting)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (options.isEmpty)
            Text('No menu options yet', style: TextStyle(color: textSecondary))
          else
            ...options.map(
              (opt) => LunchPollOptionRow(
                option: opt,
                selected: myOptionId == opt.id,
                totalVotes: total,
                enabled: canVote,
                onTap: () async {
                  if (!canVote) return;
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
                  await ref.read(lunchProvider.notifier).vote(poll.id, opt.id);
                },
              ),
            ),
          if (poll.myVote?.votedAt != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Voted ${formatLunchVoteTime(poll.myVote!.votedAt)}',
                style: TextStyle(fontSize: 11, color: textSecondary),
              ),
            ),
          ],
          if (total > 0) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => _showVotesSheet(context, poll),
                child: const Text(
                  'View all votes',
                  style: TextStyle(
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

  void _showVotesSheet(BuildContext context, LunchPoll poll) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final options = poll.mergedOptions;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'All votes — ${poll.title}',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: options.expand((opt) {
                      if (opt.voters.isEmpty) {
                        return [
                          ListTile(
                            title: Text(opt.label),
                            trailing: Text('${opt.voteCount} votes'),
                          ),
                        ];
                      }
                      return opt.voters.map(
                        (v) => ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              v.name.isNotEmpty ? v.name[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          title: Text(v.name),
                          subtitle: Text(opt.label),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
          const SizedBox(height: 8),
          Text(
            '$bal ${AppConstants.currencySymbol}',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: isOwed ? cs.error : lunchBrandGreen,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
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
          const SizedBox(width: 12),
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
