import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../data/models/lunch_model.dart';
import '../../providers/lunch_provider.dart';
import '../../widgets/crm_card.dart';
import '../../widgets/error_widget.dart' as app_widgets;
import '../../widgets/loading_widget.dart';
import 'lunch_hub_chrome.dart';
import 'lunch_poll_form_page.dart';
import 'lunch_ui_helpers.dart';

class LunchPollsAdminPage extends ConsumerStatefulWidget {
  const LunchPollsAdminPage({super.key});

  @override
  ConsumerState<LunchPollsAdminPage> createState() => _LunchPollsAdminPageState();
}

class _LunchPollsAdminPageState extends ConsumerState<LunchPollsAdminPage> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool hydrate = false}) async {
    final hadPolls = ref.read(lunchProvider).adminPolls.isNotEmpty;
    if (!hadPolls && mounted) setState(() => _loading = true);
    final now = DateTime.now();
    try {
      await ref.read(lunchProvider.notifier).loadAdminPolls(
        from: now.subtract(const Duration(days: 30)),
        to: now.add(const Duration(days: 7)),
        hydrate: hydrate,
        silent: hadPolls,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _voteTotal(LunchPoll poll) => poll.totalVoteCount;

  Future<void> _openCreatePoll() async {
    final saved = await showLunchPollFormSheet(context, ref);
    if (saved && mounted) await _load();
  }

  Future<void> _openEditPoll(LunchPoll poll) async {
    final saved = await showLunchPollFormSheet(context, ref, existing: poll);
    if (saved && mounted) await _load();
  }

  bool _canClosePoll(LunchPoll poll) => poll.canAdminClosePoll;

  Future<void> _closePollCard(LunchPoll poll) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close poll?'),
        content: Text(
          'Close "${poll.title}"? Employees will no longer be able to vote.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Close poll'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(lunchProvider.notifier).closePoll(poll.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Poll closed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not close poll: $e')),
      );
    }
  }

  Future<void> _confirmDeletePoll(LunchPoll poll) async {
    final cs = Theme.of(context).colorScheme;
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete poll', style: TextStyle(color: textPrimary)),
        content: Text(
          'Delete "${poll.title}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(lunchProvider.notifier).deletePoll(poll.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Poll deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete poll: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lunchProvider);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final primary = Theme.of(context).colorScheme.primary;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: AppThemeColors.pagePaddingAll,
        children: [
          LunchPageTitle(
            title: 'Polls',
            subtitle: 'Create and manage daily lunch polls.',
            trailing: [
              FilledButton.icon(
                onPressed: _openCreatePoll,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (_loading && state.adminPolls.isEmpty)
            const ListSkeletonLoader(itemCount: 4, shrinkWrap: true)
          else if (state.adminPollsError != null && state.adminPolls.isEmpty)
            app_widgets.ErrorWidget(
              message: state.adminPollsError!,
              onRetry: _load,
            )
          else if (state.adminPolls.isEmpty)
            app_widgets.EmptyStateWidget(
              title: 'No polls yet',
              subtitle: 'Create your first lunch poll for the team',
              icon: Icons.poll_outlined,
              buttonText: 'Create poll',
              onButtonPressed: _openCreatePoll,
            )
          else
            ...state.adminPolls.map(
              (poll) => Padding(
                padding: AppThemeColors.cardListItemMargin,
                child: CRMCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _openEditPoll(poll),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      poll.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: textPrimary,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (poll.date != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        DateFormat('EEE, MMM d, yyyy')
                                            .format(poll.date!.toLocal()),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              lunchPollStatusBadge(poll.effectiveStatus),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _MetaChip(
                            icon: Icons.how_to_vote_outlined,
                            label: '${_voteTotal(poll)} votes',
                            color: primary,
                          ),
                          const SizedBox(width: 8),
                          if (poll.endTime != null && poll.endTime!.isNotEmpty)
                            _MetaChip(
                              icon: Icons.schedule,
                              label: formatLunchEndTimeDisplay(poll.endTime),
                              color: textSecondary,
                            ),
                          const Spacer(),
                          if (_canClosePoll(poll))
                            TextButton(
                              onPressed: () => _closePollCard(poll),
                              style: TextButton.styleFrom(
                                foregroundColor:
                                    Theme.of(context).colorScheme.error,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Close'),
                            ),
                          PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_vert,
                              color: textSecondary,
                              size: 20,
                            ),
                            onSelected: (v) async {
                              if (v == 'edit') {
                                await _openEditPoll(poll);
                              } else if (v == 'close') {
                                await _closePollCard(poll);
                              } else if (v == 'votes') {
                                showLunchPollVotesSheet(context, poll);
                              } else if (v == 'delete') {
                                await _confirmDeletePoll(poll);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              if (poll.totalVoteCount > 0)
                                const PopupMenuItem(
                                  value: 'votes',
                                  child: Text('View votes'),
                                ),
                              if (_canClosePoll(poll))
                                const PopupMenuItem(
                                  value: 'close',
                                  child: Text('Close poll'),
                                ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  'Delete poll',
                                  style: TextStyle(
                                    color: Theme.of(ctx).colorScheme.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}
