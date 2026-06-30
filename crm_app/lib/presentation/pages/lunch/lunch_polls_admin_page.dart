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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final now = DateTime.now();
    await ref.read(lunchProvider.notifier).loadAdminPolls(
      from: now.subtract(const Duration(days: 30)),
      to: now.add(const Duration(days: 7)),
    );
  }

  int _voteTotal(LunchPoll poll) => poll.totalVoteCount;

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
                onPressed: () => showLunchPollFormSheet(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (state.status == LunchLoadStatus.loading && state.adminPolls.isEmpty)
            const ListSkeletonLoader(itemCount: 4, shrinkWrap: true)
          else if (state.adminPolls.isEmpty)
            app_widgets.EmptyStateWidget(
              title: 'No polls yet',
              subtitle: 'Create your first lunch poll for the team',
              icon: Icons.poll_outlined,
              buttonText: 'Create poll',
              onButtonPressed: () => showLunchPollFormSheet(context, ref),
            )
          else
            ...state.adminPolls.map(
              (poll) => Padding(
                padding: AppThemeColors.cardListItemMargin,
                child: CRMCard(
                  onTap: () => showLunchPollFormSheet(context, ref, existing: poll),
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
                                await showLunchPollFormSheet(context, ref, existing: poll);
                                await _load();
                              } else if (v == 'close' && poll.isVotingOpen) {
                                await ref.read(lunchProvider.notifier).closePoll(poll.id);
                                await _load();
                              } else if (v == 'votes') {
                                showLunchPollVotesSheet(context, poll);
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'edit', child: Text('Edit')),
                              if (poll.totalVoteCount > 0)
                                const PopupMenuItem(value: 'votes', child: Text('View votes')),
                              if (poll.isVotingOpen)
                                const PopupMenuItem(value: 'close', child: Text('Close poll')),
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
