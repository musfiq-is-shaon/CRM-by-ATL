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

  Future<void> _load({bool hydrate = true}) async {
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
    if (saved && mounted) await _load(hydrate: false);
  }

  Future<void> _openEditPoll(LunchPoll poll) async {
    final saved = await showLunchPollFormSheet(context, ref, existing: poll);
    if (saved && mounted) await _load();
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
                  onTap: () => _openEditPoll(poll),
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
                                  poll.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                    fontSize: 15,
                                  ),
                                ),
                                if (poll.date != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('EEE, MMM d, yyyy').format(poll.date!.toLocal()),
                                    style: TextStyle(fontSize: 12, color: textSecondary),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          lunchPollStatusBadge(poll.effectiveStatus),
                        ],
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
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: textSecondary, size: 20),
                            onSelected: (v) async {
                              if (v == 'edit') {
                                await _openEditPoll(poll);
                              } else if (v == 'close' && poll.isVotingOpen) {
                                await ref.read(lunchProvider.notifier).closePoll(poll.id);
                                await _load();
                              } else if (v == 'votes') {
                                showLunchPollVotesSheet(context, poll);
                              } else if (v == 'delete') {
                                await _confirmDeletePoll(poll);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(value: 'edit', child: Text('Edit')),
                              if (poll.totalVoteCount > 0)
                                const PopupMenuItem(value: 'votes', child: Text('View votes')),
                              if (poll.isVotingOpen)
                                const PopupMenuItem(value: 'close', child: Text('Close poll')),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  'Delete poll',
                                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (poll.mergedOptions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        LunchPollVoteBreakdown(poll: poll),
                        if (poll.totalVoteCount > 0)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => showLunchPollVotesSheet(context, poll),
                              icon: Icon(Icons.people_outline, size: 16, color: primary),
                              label: Text(
                                'View all votes',
                                style: TextStyle(color: primary, fontSize: 13),
                              ),
                            ),
                          ),
                      ],
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
